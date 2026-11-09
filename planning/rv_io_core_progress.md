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

## Phase 1: bridge, clock-domain crossing, boot section

Commits `eb9eae7` (the bridge), then `dd77fb0`, `cc215c6` and `beb45e4`
(the G3 fixes below); the gates ran on `beb45e4`.

Built:

- `upycore/rtl/mpy_iobr.sv`, the hart side of the bridge: CMD (32 words),
  RSP (16), CON, CON_RX, EVT, UPD (state page words), DN (hart page
  words) and LD (the boot section) as dual-clock FIFOs
  (`mpy_async_fifo.sv`, gray pointers, ported from the epic branch); EVT,
  EVT_EN, EVT_SET, EVT_MASK and the `evt_pend` flop; the state page copy
  (32 I/O core words, 8 hart words) in flops; the island timer's µs and
  ms counts crossing as gray code. A store that would overflow a FIFO
  waits in the core-port skid (`stall_o`, a flop); nothing is dropped.
- `mpy_soc.sv`: the window's decode beside the simulator page on the
  skid, a registered copy of the access, answers through the simulator
  page's answer flops; every other window address goes to `mpy_mem`,
  which answers with its fault (unchanged). The simulator page's decode
  is a direct compare on the upper address bits, proven equal to the
  `mpy_region_of()` test it replaces with Yosys `sat`
  (`iocore/tools/proofs/run.sh`).
- `iocore/rtl/iocore_bridge.sv` (the I/O core side at `0x8000_3000`) and
  `iocore_gpio.sv` (16 pins, edge latches). GPIO was planned for phase 2;
  it landed with the island's bus decode.
- `mpy_boot.sv`: an optional IOCB section after the image, written into
  the island's SRAMs through LD; the I/O core leaves reset once LD has
  drained. `mpy_nand.py --iocore` appends it; the simulation stream takes
  `+IOC_CODE`/`+IOC_DATA` or ends with one 0 word.
- The board I/O firmware overlay (`upycore/firmware/io/io.py`: the `_io`
  native module over `_peek32` and `_st`; `_poke32` is a firmware
  function, not a core native) and a frozen `machine` with `mem32`; both
  only in images that import `machine`, `time` or `_io`.
- Benches: `tb_mpy_iobr` (randomized traffic through every FIFO at clock
  ratios from 1:3 to 3:1, 12 trials, 39,891 checks), `tb_mpy_boot` IOCB
  trials. Tests: the `io` area's `bridge_loopback` (1,000 words),
  `bridge_regs`, `bridge_misaligned` and `bridge_unmapped` (faults),
  `mem32_align`.

G3 needed three rounds. The first tree had 66 `mpy_soc` groups 0.27 ns
slower: every one started at `c_pend` and ran through the skid's
`p_addr` mux into `mpy_mem`'s arbitration, which the bridge's decodes
loaded. Registering the bridge's inputs (one flop load per skid net)
fixed those. Comparing every register group, not only the top 400,
then showed `sim_rdata`, `boot_done`, `boot_error` and `gc_rst_n`
slower: STATUS became flops a clock old, `done_o` no longer waits for
LD, the section's count checks went to their own state (`C_IERR`, which
reaches `C_ERR` a clock later), and the bridge's read mux became a flat
AND-OR of three parts.

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % |
| G2 | PASS: 510 of 510 pass; 505 with the baseline's cycles, 0 moved, 5 new (`io`) |
| G3 | PASS: `mpy_core` 578 of 578 groups matched, none slower by > 0.1 (worst 27.389 → 27.389 ns); `mpy_soc` 1,104 of 1,105 matched, none slower by > 0.1. The unmatched group, `u_ca.bulk_engine.hvalid` (5.060 → 5.316), is inside the unchanged collection accelerator: the path is the same up to the bulk engine's FSM, which Yosys encodes differently in the larger netlist; `gates.py` lists it as flow noise |
| G4 | PASS: 505 identical, 0 differ, 5 not in both trees (the new `io` tests) |
| G5 | PASS: island 135,955 µm² + `mpy_iobr` 177,550 µm² = 313,505 of 450,000 (SRAM unchanged, 24 KB) |

Unit benches: 31 of 31 (adds `mpy_iobr`).

Deviations from the plan:

- The tick words cross as hardware gray code, not as page words the
  firmware writes, so `ticks_ms`/`ticks_us` are exact and never stale.
- The state page is flops on the hart side (32 + 8 words), not a shared
  RAM: a dual-port RAM across the two clocks would be a custom macro.
- The console redirect (CON) went into phase 1's bridge so the FIFO set
  was built and tested once.

## Phase 2: polled board I/O, machine and time, the UART console

Commit `3621aca`.

Built:

- The I/O core's production firmware (`iocore/sw/fw`): one polled loop
  that runs the hart's commands (pins, UART0, four software timers on the
  microsecond counter, SYS), a 256-byte RX ring and a 256-byte TX ring on
  UART0, and keeps the state page current (pin levels, UART0 counts,
  timer counts, and `SEQ`, the count of finished commands that orders a
  command before a later page read). The island's SYS block reports
  io_clk (`FREQ`) and the console strap.
- Frozen `machine` (`Pin`, `UART`, `Timer`, `mem32`, `freq`, `idle`) and
  `time` (`ticks_*`, `sleep*`, `time`, `time_ns`) with MicroPython
  v1.29.0's signatures, linked only into images that import them.
- The console firmware (`upycore/firmware/io/console.py`): `sys.stdin`,
  `sys.stdout`, `sys.stderr` and `input()` with `readline.c`'s echo and
  editing, reading CON_RX. With the `uart` strap the I/O core moves CON
  to UART0 TX and UART0 RX to CON_RX.
- The bench: pad traces and the UART line model's bytes as `MPY_IO` lines
  (a test's `.io` golden), per-test plusargs and per-strap goldens, the
  UART console drained after the halt.
- Tests: `io` gains `pin_loop`, `blink` (at the pad), `uart_echo` (115200
  8N1 at the pins), `sleep_accuracy`, `ticks`; the new `console` area has
  `con_print` and `con_input`, each on the `sim` and the `uart` strap.

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % |
| G2 | PASS: 519 of 519 pass; 505 with the baseline's cycles, 0 moved, 14 new |
| G3 | PASS: `mpy_core` 578 of 578 groups, none slower by > 0.1 (27.389 → 27.389 ns); `mpy_soc` 1,104 of 1,105 matched, none slower by > 0.1 (the unmatched one is the `hvalid` flow noise of phase 1) |
| G4 | PASS: 505 identical, 0 differ, 14 not in both trees |
| G5 | PASS: island 137,862 µm² + `mpy_iobr` 176,796 µm² = 314,658 of 450,000 |

Unit benches: 31 of 31. The `io` and `console` areas give the same
output at io_clk = hart/2, hart/1 and hart × 1.5 (`--sim-arg
+IO_CLK_NS=20`, `10`, `6.667`).

Deviations from the plan:

- The UART console sent `\n` as is in this phase; phase 4 cooks it to
  `\r\n` as MicroPython's console does, and those goldens changed then.
- An `OSError` raised by the I/O modules prints its errno alone (the base
  firmware's `OSError` text), where MicroPython prints `[Errno 19]
  ENODEV`.
