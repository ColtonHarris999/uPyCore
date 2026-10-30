# On-chip memory and boot

uPyCore has four interleaved 16,384 x 36-bit SRAM banks, sharing 256 KiB
of payload capacity between the linked image and mutable data. Each word
stores a 32-bit payload and its 4-bit tag together. There is no fixed
image/data partition. SPI NAND supplies the image at boot.

Let `I = align_up(image_bytes, 32)`. Boot maps:

| Window | Logical base | Capacity | Physical byte offset |
| --- | --- | ---: | ---: |
| Image ("flash") | `0x0000_0000` | `I` | `0` |
| Mutable data | `0x2000_0000` | `262144 - I` | `I` |

Physical word `w` selects bank `w % 4` and row `w / 4`. The split is
aligned to eight words, preserving word interleaving and 16-byte GC blocks.
Logical bases remain stable, so pointers embedded in linked images need
no relocation. Image stores fault after boot. Accesses beyond either
boot-selected window fault instead of aliasing the other window.

Runtime reservations occupy the first `0x8500` bytes of mutable data.
The GC pool starts at logical `0x2000_8500` and normally uses everything
remaining: `262144 - I - 0x8500` bytes. A nonzero image header `POOL_BYTES`
may cap that pool; boot rejects unaligned caps or caps beyond the physical
space. At least one GC block must fit. `mpy_abi.memory_layout` applies the
same checks in the linker and NAND packer. The linker reports the aligned
image, data capacity, and heap capacity in `.map.json`.

`MPY_MEM_*` in `mpy_defs.svh` describes the physical SRAM. `MPY_FLASH_*`
and `MPY_SRAM_*` sizes are maximum logical windows; the memory controller
checks their actual boot-selected ends. GC metadata is sized for the
maximum possible pool, while allocation, marking, sweeping and free-space
counters use the runtime pool size.

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
- Every master moves one tagged word per access. A 16-byte (144-bit) port
  would read four words to use one in nearly every access, costing energy.
  Instruction fetch, the one master that reads sequential words, gets its
  bandwidth from its own port and the interleaving instead.
- Payload and tag in one word is what saves the cycles: the old layout
  kept tags packed eight per word in a separate array.

## Ports and interleaving

`mpy_mem` has one port per master: the collector, the core's data
accesses, the core's instruction fetch, and the accelerator, in that
priority order. Each block takes one access per cycle. When two ports
want the same block, the higher-priority one goes first; ports that want
different blocks run in the same cycle, so up to four accesses happen at
once. The accelerator's scoreboard still
holds a core access to a word that a copy has not passed.

A load still takes two cycles: the SRAM samples the address on one edge
and the word is registered on the next, and the payload and tag come back
together on the 36-bit ack. Each port takes a new access every cycle. A
store's ack carries zero data.

What interleaving buys. On its own, little: before it, all masters shared
one port that took one access per cycle with the core first, and the core
waits for each ack before its next access, so it never waited for the
port. The accelerator can now run in the same cycle as the core (24% fewer
cycles in `tb_mpy_ca`, 54,389 to 41,090), but the `bench.py` programs ran
in the same cycle counts, because the core rarely waits for a copy.

The gain comes from instruction fetch, which reads ahead on its own port.

## Instruction fetch

`mpy_fetch` (inside `mpy_core`) keeps a queue of three bytecode words and
requests the next word whenever there is room, so the next instructions
arrive while the core executes the current one. The decoder reads up to 8
bytes from `pc` out of the queue; an instruction that needs bytes still on
their way waits for them. When `pc` leaves the queued range (a jump, a
call, a return) the queue restarts at `pc` and drops reads still in
flight. It also restarts when the core loads a frame, as the old fetch
window was dropped then.

Before this the core refilled a 12-byte window with three dependent loads
whenever `pc` left it, and stalled meanwhile: 6 to 26% of all cycles in
`bench.py`. With the queue (both accelerators on):

| Program | Before | After | |
| --- | ---: | ---: | ---: |
| dict | 316,370 | 293,130 | -7.3% |
| float | 663,409 | 540,697 | -18.5% |
| intmath | 809,016 | 638,999 | -21.0% |
| listbuild | 1,465,020 | 1,415,550 | -3.4% |
| listops | 1,265,797 | 1,148,082 | -9.3% |
| strings | 7,058,114 | 6,396,303 | -9.4% |

Those numbers are for a four-word queue; three words, the size used, are
within 0.13% of them on every program. Three is the least that always
holds 8 bytes from `pc`: at the last byte of a word, two words leave only
5 bytes, and a 6-byte instruction (a 30-bit integer constant, for one)
would wait forever. `control/fetch_long_insn` in the hardware suite puts
such instructions at every offset.

Reading ahead is speculative. A read past the end of the image faults;
the fault only matters if the decoder needs that word, and then the core
halts with the same code and address the old fetch did. Code in the data
SRAM (built by `compile`/`exec`) is read only while the accelerator is
idle, since a copy in flight may be writing it. Image reads never wait.

## Reset

After reset `mpy_mem` clears every physical SRAM row, all four banks at
once (16,384 cycles). Boot waits for this clear before writing the image,
so clearing cannot overwrite loaded words. When loading finishes, the
layout is fixed and `mpy_gc` clears its maximum-capacity allocation table.
The core and accelerator leave reset only after all three steps complete.
An invalid image count or heap cap raises `boot_err_o` and keeps them in
reset. Reset clears the full memory and metadata again, allowing a later
boot to choose a different split without retaining stale data or tags.

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
(about 346 KB) exceed the entire 256 KiB shared SRAM before runtime
reservations. Removing the partition does not make these images fit. `mpy_build.py` links the
compiler only into programs that name one of the three builtins (an AST
check, so a string or comment does not count). Those programs (the
`compiler` area of the hardware suite) fail to link with this memory map.
Running them on chip needs a smaller resident image, more physical
memory, or compiler code paged in from NAND. These are capacity failures,
not expected-failure entries in the test manifest.

## Capacity-sensitive acceptance results

The shared split does not change physical capacity. On this four-bank target,
firmware leaves roughly 42 KiB of heap for a small program. A complete
mpy-cross run of the 425 noncompiler acceptance programs passed 419. The
remaining programs were `star_wide_dir`, `star_wide_oom`, `ca_copy`,
`gc_list_shrink_reclaims`, `gc_live_exceeds_heap`, and `gc_memoryerror_recover`.
They either exhaust the available heap or produce a different result when
collection/MemoryError occurs earlier than in the oracle golden. In particular,
`star_wide_oom` reports retained memory and needs further investigation under
this smaller heap; it must not be hidden by an expected-failure marker.

Of 53 compiler-area programs, 9 passed and 44 were rejected by the linker
because their images exceed total SRAM capacity with runtime reservations.
These results are failures, not accepted exceptions: no programs are disabled
or marked expected-failure. Fitting every acceptance program requires further
memory-footprint work or more storage; a dynamic split alone cannot guarantee it.

## Simulation

`tb_mpy_soc` has an SPI NAND model (`upycore/tb/tb_spi_nand.sv`). Booting
every test over SPI would add millions of cycles to each one, so by
default `mpy_boot` takes a simulation-only shortcut. With `+IMAGE` and
`+TAGS` and no `+NAND`, it builds the same word stream from the image
files and feeds it one word per cycle. The stream decoder and the SRAM
writes are the same; only the SPI transport is skipped. That boot takes
the stream length plus the SRAM clear and GC metadata initialization.

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
