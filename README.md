# uPyCore

uPyCore is a microcontroller-class CPU whose instruction set is MicroPython
bytecode. Programs are MicroPython source. Host `mpy-cross` compiles them to
`.mpy`, the linker packs firmware and the program into a flash image, and the
Verilator model of `mpy_soc` runs that image. `compile`, `exec`, and `eval`
run the frozen uPy2 compiler on the hart: each stage is its own call, and
the firmware collects between them.

The unix oracle is MicroPython v1.29.0 built as the `upycore` variant
(`sys.platform` and `sys.implementation.name` are `upycore`).

## Run a program

Requires Python 3, Verilator 5.032 or newer, and the RV32EMC toolchain for
the USB coprocessor's firmware (`gcc-riscv64-unknown-elf` and
`picolibc-riscv64-unknown-elf`; `coproc/sw/TOOLCHAIN.md`). `make test` builds
`mpy-cross` from `vendor/micropython` when the binary is missing, and the
coprocessor firmware when a test or bench needs it.

```bash
make test
python3 upycore/tools/mpy_build.py run upycore/programs/hello.py
python3 upycore/tools/mpy_build.py oracle upycore/programs/hello.py
```

`run` prints the program's stdout and stderr and exits with the program's
status. `oracle` runs the same file on the unix port. Build that port with
`make oracle` (needs `i686-linux-gnu-gcc`).

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
`make regen-goldens` rewrites the goldens after `make oracle`. An `xfail`
entry is a known mismatch: the run is expected to fail, and a pass fails
the suite so the marker is removed with the fix. The `compiler` area calls
`compile`, `exec`, and `eval` on the hart, including `yield` and `yield from`.
Those programs take minutes each; `make test-hw-compiler` runs that area
on its own. The `generators` area is the runtime suite. Host uPy2 matches
`mpy-cross` on those programs, so they are in the byte compare too.

The SoC areas run on the peripheral window and their goldens are written
by hand: `core` (MMIO steering and faults, the heap lock, the mailbox
natives), `irq` (callbacks, the schedule ring, Ctrl-C, timers and pins),
`io` (UART, GPIO, PWM, SPI, I2C, ADC), `system` (watchdog, system reset,
the UART console, the REPL), `coproc` (the RV32EMC USB coprocessor and its
mailbox), and `usb` (a full-speed host model on the bench enumerates the
coprocessor's CDC function and drives the console over it). The registers
are `upycore/docs/mpy_peripherals.md`; the coprocessor is
`upycore/docs/mpy_coproc.md`.

```bash
python3 upycore/tools/hw_tests.py --list
python3 upycore/tools/hw_tests.py --area alu
python3 upycore/tools/hw_tests.py 'dict*'
```

## Synthesis

The hart and its components are written for a Yosys + yosys-slang backend
pass (OSS CAD Suite). `make synth` elaborates every top; `make synth-gates`
maps the logic tops (`mpy_core`, `mpy_alu`, decode, peripherals, …). Full-size
`mpy_gc` / `mpy_mem` / `mpy_soc` stay elaborate-only unless named explicitly
(gate-map a reduced collector with
`python3 upycore/tools/mpy_synth.py --synth --gc-pool-bytes=4096 mpy_gc`).
Set `SYNTH_TOP=…` to limit the run. Logs land in `build/synth/`.

```bash
make synth
make synth SYNTH_TOP=mpy_core
make synth-gates SYNTH_TOP=mpy_alu
```

Sim-only flash load (`+IMAGE` / `$readmemh`) and the GC table clear loop are
behind `` `ifndef SYNTHESIS `` so the same RTL feeds Verilator and the
backend flow.

## Layout

| Path | Role |
| --- | --- |
| `upycore/rtl` | Hart, datapath, memory, and collector |
| `upycore/firmware` | Device firmware, MicroPython source joined into one `.mpy` |
| `upycore/tools` | Image linker, ABI tables, and `mpy_build.py` |
| `upycore/programs` | Example programs |
| `coproc` | The USB coprocessor: `coproc_top.sv` (CVE2, SRAMs, mailbox side, no2usb SIE) and its TinyUSB firmware in `coproc/sw` |
| `upycore/targets/upycore.json` | Pinned bytecode catalog |
| `variants/upycore` | 32-bit unix oracle |
| `vendor/micropython` | MicroPython v1.29.0 pin |
| `planning/` | Design history for the move off the CPython hart |

Clone with the MicroPython pin:

```bash
git clone --recurse-submodules <this-repo>
```

`make test` covers a hello program and a raised `ValueError`.
