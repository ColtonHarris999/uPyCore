# Board I/O through an RV32 I/O core: progress

Plan: [`rv_io_core_plan.md`](rv_io_core_plan.md). As-built design:
[`upycore/docs/mpy_io_core.md`](../upycore/docs/mpy_io_core.md). One section
per phase, appended when the phase's gates have run.

## How the gates are run

Baseline: `main` `c895f2d`, in its own worktree, simulator built there and
kept (`basesim/Vtb_mpy_soc`), its hardware suite log kept (505 of 505 pass
in 2,683 s at `-j 3`), its unit benches (28 of 28) and its STA runs
(`mpy_core`, `mpy_soc`, unmapped, `--groups 400`) kept. Each phase's
commit is checked out in its own worktree and `iocore/tools/gates.py`
compares it with the baseline:

| Gate | Command | Pass |
| --- | --- | --- |
| G1 | `gates.py g1` (runs `clock_bench.py --before <base sim> --after <phase sim>`) | every workload 0 cycles changed |
| G2 | `hw_tests.py --area all -j 3` on the phase's tree, then `gates.py g2 <base log> <phase log>` | every test passes; every test that does not use board I/O has the baseline's `cycles=` |
| G3 | `sta/run.py mpy_core` and `mpy_soc --groups 400`, then `sta_lite.py` with every group, then `gates.py g3` | no group of either top slower by more than 0.1 |
| G4 | `gates.py g4 <base tree>` over `build/hw/*/image{.hex,.tags.hex}` of both suite runs | every image of a test without board I/O byte-identical |
| G5 | `iocore/tools/island_measure.py` (island and hart-side bridge) | within the phase 0 budget |

"Uses board I/O" is decided per test: its area is `io`, `irq`, `system`,
`console` or `usb`, or `mpy_build.io_imports()` finds an I/O import (or
console use) in its sources. G3 compares the run's top-400 list and, from
phase 1 on, every register group (`sta_lite.py` with a count of 5,000
over the same netlist), since a group below the 400 cutoff can get slower
without appearing in the list.

Environment: Verilator 5.038 (PyPI `verilator==5.38.0`, PCH flag and
wrapper as in the task notes), `mpy-cross` 1.29.0.post2, YoWASP Yosys
0.70 with slang, sky130 `tt_025C_1v80` liberty, Ubuntu's
`gcc-riscv64-unknown-elf` 13.2 and `picolibc-riscv64-unknown-elf` 1.8.6.

## Phase 0: island spike

Built:

- `iocore/rtl/iocore_top.sv`: the I/O core, a 16 KB code SRAM
  (instruction port and load port) and an 8 KB data SRAM (data port and
  load port), both one-port macros; a SYS block (id, debug byte, halt,
  interrupt controller); `iocore_timer.sv` (cycle, µs and ms counters, one
  compare on MTIP); `iocore_uart.sv` (8N1, 16-byte FIFOs, the epic
  branch's serializer and receiver rules).
- `iocore/rtl/iocore_cpu.sv`: CVE2 (`vendor/cve2`, `d7f2156`, RV32EMC) or
  Hazard3 (`vendor/hazard3`, `8af9929`, the team's benchmark commit,
  configured RV32EMC) behind one OBI-style bus, reset at `0x80`, vectored
  `mtvec` at 0, so one firmware image runs on both.
  `iocore_ahb2obi.sv` adapts Hazard3's AHB-Lite ports.
- `iocore/sw`: crt0, a linker script that puts `.rodata` and `.data` in
  data SRAM (both SRAMs are loaded, so nothing is copied), size checks
  against the SRAMs and the 14 + 7 KB budget, `bin2hex.py`, and the
  `hello` firmware. `TOOLCHAIN.md` is the epic branch's recipe; Ubuntu
  packages it.
- `iocore/tb/tb_iocore.sv` and `tb_uart_line.sv` (an 8N1 terminal). The
  `hello` firmware prints over the UART, waits on the timer, takes a timer
  interrupt and echoes two received bytes on both cores
  (`unit_tests.py iocore_cve2 iocore_hazard3`).
- `iocore/tools/island_measure.py` (mapped area, unmapped timing),
  `iocore/tools/gates.py`; `upycore/tools/sta/run.py` takes an explicit
  file list, include directories and parameters.

Decision D1, from `upycore/docs/mpy_io_core.md` (numbers in
`mpy_io_core_island_phase0.json`):

| | CVE2, slow MUL | CVE2, fast MUL | Hazard3, seq MUL | Hazard3, fast MUL |
| --- | ---: | ---: | ---: | ---: |
| Core area, µm² | 87,177 | 99,328 | 72,189 | 90,679 |
| Island area, µm² | 116,018 | 127,400 | 100,518 | 119,138 |
| Island flops | 2,072 | 2,076 | 1,857 | 1,922 |
| Worst path, unmapped STA, ns | 18.21 | 18.09 | 18.07 | 17.94 |

Chosen: **CVE2 with the iterative multiplier**. Timing is the same.
Hazard3 is 15,000 µm² (13 % of the island, about 0.015 mm²) smaller, which
counts for little next to the island and the SoC; integration decides it:
CVE2's bus is the island's bus (Hazard3 needs the AHB adapter and a wait
state on every store), and the epic branch's TinyUSB port and firmware
layout run on CVE2 already. Both islands run the same firmware, so the
choice can still be revisited.

Budget for gate G5, set here for review: everything the I/O work adds,
excluding SRAM macros (island, peripherals, USB SIE, and the hart-side
bridge with its clock-domain crossings) at most **450,000 µm²** in this
flow; SRAM at most **28 KB** (16 KB code, 8 KB data, at most 4 KB of USB
endpoint buffers).

Gates (phase 0 changes no hart RTL, firmware or tool that builds an
image):

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % (AES, Fannkuch, the 10 timing loops, pystone, the 11 project programs) |
| G2 | PASS: 505 of 505, all 505 with the baseline's cycles |
| G3 | PASS: `mpy_core` 578 groups, `mpy_soc` 1,105 groups, all equal to the baseline |
| G4 | PASS: 505 of 505 images byte-identical |
| G5 | 116,018 µm² of 450,000; 24 KB SRAM of 28 |

Unit benches: 30 of 30 (the baseline's 28 and the two island benches).

Deviations from the plan:

- The plan's phase 0 line says 8 + 4 KB SRAMs; §3.1 says 16 + 8 KB. The
  islands were built and measured with 16 + 8 KB, the size the firmware
  needs. The SRAMs are macros, so the logic area does not depend on it.
- Simulation note: CVE2's registers sit behind its own clock gate, so in
  Verilator they see only an asynchronous reset edge. The island's core
  reset starts released in simulation (`initial`), so its first assertion
  is an edge; synthesis does not see the `initial`.
- Hazard3 read with yosys-slang warns about its static Verilog functions
  (arguments driven from several always blocks). Read with Yosys's own
  Verilog frontend and the same parameters, the core alone is 69,769 µm²
  and 1,137 flops, which agrees with slang's 72,189 µm² once the two AHB
  adapters are counted, so the slang netlist was used for both cores.
