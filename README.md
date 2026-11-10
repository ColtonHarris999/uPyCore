# uPyCore

uPyCore is a microcontroller-class CPU whose instruction set is MicroPython
bytecode. Programs are MicroPython source. Host `mpy-cross` compiles them to
`.mpy`, the linker packs firmware and the program into an image, and the
Verilator model of `mpy_soc` boots it into its on-chip image SRAM and runs
it. `compile`, `exec`, and `eval` run the frozen uPy2 compiler on the hart:
each stage is its own call, and the firmware collects between them. The
512 KiB shared SRAM holds the compiler and firmware together; the remaining
space supplies its runtime heap (see Memory and boot).

The unix oracle is MicroPython v1.29.0 built as the `upycore` variant
(`sys.platform` and `sys.implementation.name` are `upycore`): 32-bit,
long-long ints, binary32 floats evaluated in SSE (no x87 excess precision),
so its float results are those of a binary32 MCU.

Status: every program in the hardware suite passes on the simulator. The
last post-route timing result is 18 ns; the RTL now estimates about 10.5 ns
([`timing_10ns.md`](upycore/docs/timing_10ns.md)), and 10 ns post-route is
not yet shown. The SoC has no UART, GPIO or timer: console output is a byte
port and the image boots from SPI NAND (`mpy_periph` is unit-tested but not
integrated). Language and library gaps are in
[`known_limitations.md`](upycore/docs/known_limitations.md).

## Run a program

Requires Python 3.11 or newer and Verilator 5.032 or newer. `make test`
builds `mpy-cross` from `vendor/micropython` when the binary is missing.
[`TESTING.md`](TESTING.md) lists every test layer and its requirements.

```bash
make test
python3 upycore/tools/mpy_build.py run upycore/programs/hello.py
python3 upycore/tools/mpy_build.py oracle upycore/programs/hello.py
```

`run` prints the program's stdout and stderr and exits with the program's
status. `oracle` runs the same file on the unix port. Build that port with
`make oracle` (needs `i686-linux-gnu-gcc` and the i386 loader, `libc6-i386`
or `libc6:i386`).

## Hardware suite

`upycore/programs/hw_tests.toml` is the suite. Each entry is a MicroPython
program under `upycore/programs/hw/`. The host compiles it with `mpy-cross`,
links that bytecode and the firmware into a flash image, and the simulator
boots the image so `_boot` runs the program. The run passes when stdout,
stderr, and the exit status match the golden files beside the source.
Those files are the unix oracle's output. `make test` runs the suite twice:
once from `mpy-cross` bytecode and once from the vendored uPy2 compiler
(`vendor/upy2`, `mpyc`). `make test-compiler` is the second run on its own,
plus a byte compare of the two compilers.
`make regen-goldens` rewrites the goldens after `make oracle`. The manifest
checks reject expected-failure and disabled entries: every listed program
must pass. Remaining runtime limitations are documented in
[`upycore/docs/known_limitations.md`](upycore/docs/known_limitations.md).
The `compiler` area calls
`compile`, `exec`, and `eval` on the hart, including `yield` and `yield from`.
Those programs take minutes each; `make test-hw-compiler` runs that area
on its own. The `generators` area is the runtime suite. Host uPy2 matches
`mpy-cross` on those programs, so they are in the byte compare too.

```bash
python3 upycore/tools/hw_tests.py --list
python3 upycore/tools/hw_tests.py --area alu
python3 upycore/tools/hw_tests.py 'dict*'
```

## Unit testbenches

`upycore/tb` has one testbench per block (ALU, container accelerator,
decoder, collector, peripherals, register file and memory, the probe
modulo). `make test-unit` verilates each with the RTL it needs and runs
it with its inputs; CI runs it as the `unit` job.

```bash
python3 upycore/tools/unit_tests.py
python3 upycore/tools/unit_tests.py alu gc
```

## Accelerators

The collection accelerator (`mpy_collection`) holds the word and byte copy
engines, the bulk map engine with its MicroPython-compatible hash unit and
hash-to-slot rehash pipeline, and the short-list engine for small list
operations ([`collection_accelerator.md`](upycore/docs/collection_accelerator.md),
[`mpy_hash.md`](upycore/docs/mpy_hash.md),
[`shortlist_engine.md`](upycore/docs/shortlist_engine.md)).

Bulk word copies run on the container accelerator while the core goes on
to the next instruction, and a binary op that cannot fail retires before
the ALU finishes. A scoreboard makes a later access to busy data wait.
[`upycore/docs/mpy_ca.md`](upycore/docs/mpy_ca.md) has the rules and the
measurements. `python3 upycore/tools/bench.py` compares the switches,
and `mpy_build.py run --sim-arg +CA=0 --sim-arg +AALU=0` turns both off.

## Memory and boot

Both memories are on-chip SRAM built from four 128 KiB banks of 36-bit
words (payload and tag in one word), interleaved by word. Each bank is
eight 4096 x 36 SRAM macros: a single 32768-word macro is 31 mm long and
too slow for a 10 ns clock. Image and data
share their 512 KiB payload capacity: boot rounds the actual image size
up to 32 bytes and gives all remaining space to mutable data. Logical
image/data addresses stay unchanged; there is no fixed partition. The collector, the core,
the core's instruction fetch and the container accelerator each have a
memory port, and ports that touch different blocks run in the same cycle.
Fetch reads three words ahead of `pc`. After reset `mpy_boot` copies the
image from an SPI NAND flash into the image SRAM, then the core starts. `--nand` boots a run over SPI from
the testbench's NAND model; without it the simulation streams the image
files straight into the loader.
[`upycore/docs/mpy_boot.md`](upycore/docs/mpy_boot.md) has the boot
stream, the SPI commands, why the blocks are one 36-bit port, and the
EE 477 SRAM macro setup.

```bash
python3 upycore/tools/mpy_build.py run -v --nand upycore/programs/hello.py
python3 upycore/tools/mpy_nand.py build/mpy/run/hello/image   # image.nand.bin for the flash
```

## Synthesis

The hart and its components are written for a Yosys + yosys-slang backend
pass (OSS CAD Suite). `make synth` elaborates every top; `make synth-gates`
maps the logic tops (`mpy_core`, `mpy_alu`, decode, peripherals, …). `mpy_gc`,
`mpy_mem` and `mpy_soc` (whose SRAM blocks are macros in the class flow) stay
elaborate-only unless named explicitly
(gate-map a reduced collector with
`python3 upycore/tools/mpy_synth.py --synth --gc-pool-bytes=4096 mpy_gc`).
Set `SYNTH_TOP=…` to limit the run. Logs land in `build/synth/`.

```bash
make synth
make synth SYNTH_TOP=mpy_core
make synth-gates SYNTH_TOP=mpy_alu
```

`mpy_synth.py --depth LEVELS` maps a top flat to generic gates (without
cross-unit resource sharing) and ranks
every register endpoint by logic depth (`upycore/tools/depth_report.py`),
listing those at least `LEVELS` deep with the register each path starts
from. Levels compare designs; they are not nanoseconds.

```bash
python3 upycore/tools/mpy_synth.py --depth 100 mpy_core
```

Sim-only flash load (`+IMAGE` / `$readmemh`) and the GC table clear loop are
behind `` `ifndef SYNTHESIS `` so the same RTL feeds Verilator and the
backend flow.

## Layout

| Path | Role |
| --- | --- |
| `upycore/rtl` | Hart, datapath, memory, collector and accelerators |
| `upycore/firmware` | Device firmware, MicroPython source joined into one `.mpy` |
| `upycore/runtime` | `array`, `math`, `cmath`, `random`, `io`: frozen into programs that import them |
| `upycore/compiler` | On-device driver for the frozen uPy2 compiler |
| `upycore/tools` | Image linker, ABI tables, `mpy_build.py`, test runners and benchmarks |
| `upycore/tests` | Host unit tests |
| `upycore/tb` | RTL unit testbenches |
| `upycore/programs` | Hardware suite (`hw/`, `hw_tests.toml`), benchmarks and examples |
| `upycore/targets/upycore.json` | Pinned bytecode catalog |
| `upycore/synth` | Design Compiler and Hammer (Genus/Innovus) flow scripts |
| `upycore/docs` | As-built design documents and recorded measurements |
| `variants/upycore` | 32-bit unix oracle |
| `vendor/micropython` | MicroPython v1.29.0 pin |
| `vendor/upy2` | The uPy2 compiler (`mpyc`) |
| `planning/` | Open plans and the archived design history |

Clone with the MicroPython pin:

```bash
git clone --recurse-submodules <this-repo>
```

Third-party code and its terms are listed in [`NOTICE.md`](NOTICE.md).
