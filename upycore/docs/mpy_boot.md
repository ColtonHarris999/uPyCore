# On-chip memory and boot

uPyCore's two memories are on-chip SRAM: a 64 KB data SRAM and a 192 KB
image SRAM that holds the linked image (the window at address 0 that the
rest of the docs call flash). Both live in four identical 64 KB blocks,
interleaved by word. The image comes from an SPI NAND flash: `mpy_boot`
copies it into the image SRAM after reset, before the hart starts.

| Window | Base | Size | Rows of every block |
| --- | --- | ---: | --- |
| Data SRAM | `0x2000_0000` | 64 KB | 0 to 4095 |
| Image SRAM ("flash") | `0x0000_0000` | 192 KB | 4096 to 16383 |

Word `w` of either window is in block `w % 4` (address bits `[3:2]`), so
consecutive words sit in different blocks. The constants are in
`upycore/rtl/mpy_defs.svh` (`MPY_MEM_*`, `MPY_SRAM_BLOCKS`,
`MPY_IMAGE_BLOCKS` give the sizes), `upycore/tools/mpy_abi.py`
(`SRAM_BYTES`) and `upycore/tools/mpy_link.py` (`FLASH_BYTES`). The frame
stack, root area and argument buffer keep their 0x8500 bytes at the bottom
of the data SRAM, so the GC pool is 31,488 bytes (1,968 blocks).

## SRAM blocks

Every block is `bsg_mem_1rw_sync_mask_write_bit` from BaseJump STL with
`els_p = 16384` and `width_p = 36`: one read/write port and a per-bit write
mask. A word is `{tag[3:0], payload[31:0]}`, so one access reads a value
and its tag together, and one write stores both. The mask turns a byte
store, or a payload store that keeps the tag, into one write instead of a
read and a write. In the EE 477 flow each block becomes a
`fakeram_d16384_w36` macro.

Why one 36-bit port per block:

- `bsg_fakeram` generates only one-port (1rw) memories with a bit mask, so
  two 4-byte read/write ports per block cannot be generated. A two-port
  SRAM would also be about twice the area of a one-port SRAM of the same
  size.
- The core, the collector and the accelerator each move one tagged word
  per access. A 16-byte (144-bit) port would read four words to use one in
  nearly every access, costing energy, and it needs line buffers in the
  core before it saves any cycles. Both options give the same capacity
  from the same macro area. If instruction fetch later reads a whole
  12-byte window at once, a wider image SRAM is the place to start.
- Payload and tag in one word is what saves the cycles: the old layout
  kept tags packed eight per word in a separate array.

## Ports and interleaving

`mpy_mem` has one port per master: the collector, the core and the
accelerator. Each block takes one access per cycle. When two ports want
the same block, the collector goes first, then the core, then the
accelerator; ports that want different blocks run in the same cycle, so
up to three accesses happen at once. The accelerator's scoreboard still
holds a core access to a word that a copy has not passed.

A load still takes two cycles: the SRAM samples the address on one edge
and the word is registered on the next, and the payload and tag come back
together on the 36-bit ack. Each port takes a new access every cycle. A
store's ack carries zero data.

What interleaving buys. Before it, all masters shared one port that took
one access per cycle, and the core had priority over the accelerator. The
core waits for each ack before its next access, so it never waited for the
port; the accelerator used the cycles in between. Now the accelerator can
run in the same cycle as the core. In `tb_mpy_ca`, where the core keeps
touching words a copy owns, that is 24% fewer cycles (54,389 to 41,090).
On the `bench.py` programs the cycle counts are identical to the cycle:
the core rarely waits for a copy to finish. Interleaving pays off once a
master issues more than one access per cycle or does not wait for each
ack (instruction fetch running ahead, for example).

## Reset

After reset `mpy_mem` writes zero to every data SRAM word, all four blocks
at once (4,096 rows), and grants nothing until it is done. A loader write
during the clear takes its block for that cycle and the clear repeats the
row, so the clear finishes after 4,096 cycles without a loader write. `mpy_gc` clears its allocation
table (one entry per cycle, 1,968 cycles) at the same time. A real SRAM
or flop does not power up as zero, so neither can rely on an `initial`
block.

`upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv` is a behavioral stand-in
with BaseJump's name and ports, for Verilator and Yosys. The class flow
must use BaseJump's file instead (see below).

## Boot

`mpy_soc` holds the core and the accelerator in reset until three things
are done: the data SRAM clear, the allocation table clear, and the image
load. `boot_done_o` rises when the core starts, and the program's cycle
counter starts there too. If the boot stream is bad, `boot_err_o` rises
and the core never starts.

### Boot stream

`upycore/tools/mpy_nand.py <image>` writes `<image>.nand.bin` from the
linker's `<image>.hex` and `<image>.tags.hex`. Program it at page 0. It is
little-endian 32-bit words:

| Word | Contents |
| --- | --- |
| 0 | `MPY_BOOT_MAGIC`, bytes `UPYB` (`0x42595055`) |
| 1 | Image word count `n` (1 to 49,152) |
| then, `ceil(n/8)` times | One packed tag word (nibble `i` is the tag of word `i` of the group), then eight image words |

The last group is padded with zero words. Each image word is written with
its tag in one SRAM write. The stream ignores page boundaries. A
200 KB image is about 100 pages of 2 KiB.

### SPI NAND

`mpy_boot` talks to a standard SPI NAND (Winbond W25N, GigaDevice GD5F,
Micron MT29F) in SPI mode 0 with one data line each way:

1. `FFh` reset, then `0Fh C0h` status reads until OIP (bit 0) clears.
2. For each page from `FIRST_PAGE`: `13h` page read with the page
   address in the low 16 bits of the 3 address bytes, status polls until
   OIP clears, then `03h` read from cache at column 0 with one dummy byte,
   2048 bytes.

SCK is `clk / (2 * SPI_DIV)`; the default `SPI_DIV = 2` gives 25 MHz SCK
at a 100 MHz core clock. `POWERUP_CYCLES` waits before the first command,
for the flash's power-up time; set it for the board's clock and flash.
Pins on `mpy_soc`: `nand_sck_o`, `nand_cs_n_o`, `nand_mosi_o`,
`nand_miso_i`.

A 179 KB image (the firmware and a small program) boots in about 7.3M
cycles over SPI, 73 ms at 100 MHz. Not done yet:

- quad-SPI reads (`6Bh`/`EBh`), which would make the copy four times faster
- skipping bad blocks; blocks 0 and 1 hold the image, and vendors
  guarantee block 0
- a checksum over the stream

## The frozen compiler does not fit

The firmware and `array` link to 176 KB. The frozen uPy2 compiler that
`compile`, `exec` and `eval` run is another 167 KB, so images with it
(346 KB) do not fit the 192 KB image SRAM. `mpy_build.py` links the
compiler only into programs that name one of the three builtins (an AST
check, so a string or comment does not count). Those programs (the
`compiler` area of the hardware suite) fail to link with this memory map.
Running them on chip would need the compiler paged in from NAND.

## Simulation

`tb_mpy_soc` has an SPI NAND model (`upycore/tb/tb_spi_nand.sv`). Booting
every test over SPI would add millions of cycles to each one, so by
default `mpy_boot` takes a simulation-only shortcut. With `+IMAGE` and
`+TAGS` and no `+NAND`, it builds the same word stream from the image
files and feeds it one word per cycle. The stream decoder and the SRAM
writes are the same; only the SPI transport is skipped. That boot takes
about 52K cycles, and the SRAM clear runs in parallel.

```bash
python3 upycore/tools/mpy_build.py run -v upycore/programs/hello.py          # shortcut
python3 upycore/tools/mpy_build.py run -v --nand upycore/programs/hello.py   # over SPI
```

The halt line reports `boot=<cycles>`. `--nand` writes the `.nand.bin` and
`.nand.hex` files next to the image.

## EE 477 Hammer flow

`upycore/synth/hammer/make_hammer_design.py` sets up a top with SRAM
(`mpy_soc`, `mpy_mem`) for the class flow. It:

- leaves the stand-in model out of `v/`
- lists BaseJump's `bsg_mem_1rw_sync_mask_write_bit.v`, its synth model
  and helpers in `src.yml` (with the `subst` meta for `${bsg_root}`)
- adds `fakeram_d16384_w36` to `vlsi.inputs.sram_parameters`

```bash
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477-designs-module1/pow2 ~/ee477-designs-module1/upycore_soc \
    --top mpy_soc --period 20 --die 4000 3000 \
    --core-v upycore/synth/hammer/converted/mpy_core.v
cd ~/ee477-designs-module1/upycore_soc
make sram
```

`--core-v` takes the core from the sv2v-converted file, because Genus
cannot parse `mpy_core.sv`, and writes the rest (`mpy_gc`, `mpy_ca`,
`mpy_mem`, `mpy_boot`, `mpy_soc`) as SystemVerilog. If Genus also rejects
those modules, convert the whole `mpy_soc` with `convert_rtl.sh` instead.

After `make sram`, read the macro size from the generated
`fakeram_d16384_w36.lef` (`SIZE w BY h`) and pick a die that holds four
macros plus the logic. `--die` is a starting guess. Then follow Module 2
Task 3:

1. `make par-to-floorplan`, move the four macros inside the die, and note
   each one's `location` and full instance path from Object Attributes.
2. Add a `hardmacro` entry per block under `vlsi.inputs.placement_constraints`.

The paths look something like `mpy_soc/u_mem/g_blk[0].ram/macro.mem` to
`g_blk[3]`; every block holds a quarter of the data SRAM and of the image,
so they are equally busy and the core's logic should sit near all four. Copy
the exact names from Innovus.

```yaml
  - path: "mpy_soc/u_mem/g_blk[0].ram/macro.mem"
    type: hardmacro
    x: <x>
    y: <y>
    orientation: r0
```

Mirror (`mx`, `my`) but do not rotate the macros: rotating them breaks
their power rails. After `make syn`, the mapped netlist should instantiate
`fakeram_d16384_w36` four times (`grep -c fakeram_d16384_w36
build/syn-rundir/mpy_soc.mapped.v`). If a block shows up as
`notmacro.synth`, its depth or width does not match the `sram_parameters`
entry and Genus is building 590K bits of flops. A run that takes far
longer than the core alone is the same symptom.

The design folder is set up for synthesis and place and route (`make sram`,
`make syn`, `make par-to-floorplan`, `make par`). Its testbench lists are
empty, so the class simulation targets (`make sim-rtl-hard`, `make
sim-par`) do not run there yet. Simulate with this repo's Verilator flow
(`mpy_build.py run`, `--nand`) instead.
