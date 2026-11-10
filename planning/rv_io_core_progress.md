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
| G3 | `sta/run.py mpy_core` and `mpy_soc --groups 400`, then `sta_lite.py` with every group, then `gates.py g3`; for the final tree both trees with `--no-fsm` (Final) | no group of either top slower by more than 0.1 |
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

## Phase 3: events on the hart

Commit `e65d7d9`.

Built:

- `mpy_core.sv`, the plan's only core changes: a `soft_pt` flop set when
  a jump retires in a non-firmware frame (`JUMP`, `POP_JUMP_IF_*`,
  `JUMP_IF_*_OR_POP`, `POP_EXCEPT_JUMP`, `UNWIND_JUMP`'s last jump) and
  cleared in `S_DEC`; one `S_FETCH` arm, `soft_pt && evt_q`, to a new
  `S_IRQ` state that calls the `_irq_dispatch` hook and returns to
  `S_FETCH` with the pc unchanged. The `_wfe` native waits in `S_WFE` for
  an event or a timeout. `_hlock`/`_hunlock` move a heap-lock depth;
  `S_AL` goes to a new `S_HLK` while it is not 0 and raises
  `MemoryError`. The natives and the optional hook are emitted only into
  images with the board I/O firmware. No per-opcode check.
- The board I/O firmware's `irq.py`: `KBD` (KeyboardInterrupt), `PIN`,
  `TIMER` and `UART0` dispatch from state-page counts, at most one
  scheduled callback per soft point, an 8-deep `micropython.schedule`;
  real `heap_lock`, `heap_unlock`, `kbd_intr`. `machine` gains
  `Pin.irq`, Timer callbacks, `UART.irq`, `disable_irq`/`enable_irq`,
  `idle`; `time` sleeps in `_wfe`. The I/O core counts pin edges, raises
  the events and turns the armed Ctrl-C into `KBD`. The bridge gains
  `CMD_SENT` (the command fence) and `EVT_MASK` bit 1.
- Tests: the `irq` area (`sched`, `heap_lock`, `pin_irq`,
  `pin_irq_hard`, `timer_cb`, `disable_irq`, `uart_irq`, `ctrl_c`).

The first core change made seven `mpy_core` groups slower in G3 (the
response, `aalu_ret`, `al_gc` and others): the dispatch and the locked
raise got their own states (`S_IRQ`, `S_HLK`) so the existing `S_FETCH`
and `S_AL` arms kept their logic, and the clears became unconditional.

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % |
| G2 | PASS: 527 of 527 pass; 505 with the baseline's cycles, 0 moved, 22 new |
| G3 | PASS after review; `gates.py` as it stood reported FAIL. `mpy_core`: 577 of 578 groups matched (the other is an anonymous Yosys net renumbered by the new logic, `$7118y` → `$7121y`: same start, 61 cells, 13.196 → 13.178 ns), none slower by > 0.1 (27.389 → 27.389 ns). `mpy_soc`: 1,104 of 1,105 matched; besides the phase 1 `hvalid` noise, `u_ca.bulk_engine.engine.equality.a_i` went 5.348 → 5.485 ns (+0.137). That path is inside the collection accelerator, whose RTL is unchanged: from the SRAM read data, through `mpy_map_engine.sv` lines 104 to 306, it is the baseline's cell for cell (same arrival, 4.019 ns, at line 306), and its read-data net has the same nine loads; only the last cells, Yosys-generated pattern and reduce logic with no source line, split into one more AND level. `gates.py` now lists it with `hvalid` as flow noise |
| G4 | PASS: 505 identical, 0 differ, 22 not in both trees |
| G5 | PASS: island 137,862 µm² + `mpy_iobr` 179,157 µm² = 317,019 of 450,000 |


Unit benches: 31 of 31. The `irq` area gives the same output at io_clk =
hart/2, hart/1 and hart × 1.5.

Deviations from the plan:

- `hard=True` handlers run at the next soft point with the heap locked
  (decision D2), tens to hundreds of hart cycles after the event, not
  inside the interrupt.
- Ctrl-C, callbacks and the schedule exist only in images with the board
  I/O firmware; a program with none of the I/O imports is not
  interrupted by Ctrl-C.
- `Pin.irq` coalesces edges that arrive before the handler runs.
- An exception from a hard handler has no traceback frames (none can be
  recorded with the heap locked), so it prints no `Traceback` header, as
  `py/obj.c` does then.

## Phase 4: remaining peripherals, system reset, the REPL

Commits `7645cc8` and `fec3269` (the register stage for the ported
blocks); the gates ran on `fec3269`.

Built:

- The epic branch's PWM, SPI, I2C, ADC, watchdog and pin-mux blocks as
  `iocore_*` on the island's bus, their register logic unchanged. Two
  changes to the watchdog: an expiry stops it (the island is not reset
  with the hart, so a running watchdog would reset the hart every tick)
  and a stop key the firmware uses for `machine.reset()`. Every access to
  the six blocks goes through a register stage (`fec3269`): their write
  logic from CVE2's store address had pushed the island's worst
  open-flow path from 18.21 to 21.82 ns; with the stage it is 18.93 ns.
- `machine` gains `PWM`, `SPI`, `I2C`, `ADC`, `WDT`, `reset`,
  `soft_reset`, `reset_cause`, `unique_id`.
- System reset: `mpy_soc` splits `pwr_n` (power on) from `por_n`, which a
  system reset request (`SYS_RESET`, the watchdog) holds low for 32
  clocks; the island, the bridge, `RESET_CAUSE` and `KEEP` stay up.
  Before it the I/O core puts the peripherals back (`SYS RESET`).
- The REPL (`upycore/firmware/io/repl.py`, REPL images only):
  MicroPython v1.29.0's friendly REPL (banner, `__repl_print__`,
  continuation with auto-indent, paste mode, Ctrl-A to E) and raw REPL
  with raw-paste mode, following `pyexec.c` and `readline.c`; the mode
  survives a soft reboot in `KEEP`. The I/O core cooks console output
  (`\n` as `\r\n`).
- The bench: `+UART_SCRIPT` host sessions, the SPI flash, I2C target and
  ADC models. Unit benches: the epic's PWM, SPI, I2C and ADC benches,
  ported, and a new watchdog bench.
- Tests: the `system` area (`pwm_duty`, `spi_flash`, `i2c_mem`, `adc`,
  `wdt`, `reset_soft`, `reset_hard`) and the `console` area's
  `repl_friendly` and `repl_raw` (an `mpremote` session, raw-paste
  included).

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % |
| G2 | PASS: 536 of 536 pass; 505 with the baseline's cycles, 0 moved, 31 new |
| G3 | PASS: `mpy_core` 577 of 578 matched (the renumbered anonymous net of phase 3), none slower by > 0.1; `mpy_soc` 1,104 of 1,105 matched, none slower by > 0.1 beyond the `hvalid` noise. Phase 3's `equality.a_i` is back within 0.1 ns, as flow noise would be |
| G4 | PASS: 505 identical, 0 differ, 31 not in both trees |
| G5 | PASS: island 175,207 µm² + `mpy_iobr` 180,577 µm² = 355,784 of 450,000 |


Unit benches: 36 of 36 (adds the PWM, SPI, I2C, ADC and watchdog benches).

Deviations from the plan and test changes:

- The UART-console goldens (`con_print_uart`, `con_input_uart`,
  `ctrl_c`) changed with the output cooking.
- `uart_echo` and `uart_irq` send their bytes 8 ms after boot instead of
  3 and 4 ms: `import machine` grew to about 3.5 ms with the phase 4
  classes, and the bytes arrived before the programs were ready.
- A command word with bit 31 set (channel `0x80` and up) is written as a
  negative int: `_st` stores a small int's payload, and `0x80000000` is
  not one (the watchdog's commands were lost until this was found).
- A REPL image is an image built with `repl=True`, which runs its
  program (an empty one in the tests) before the REPL, as rp2 runs
  `main.py`; the plan's "no program in the image" is the empty program.
- History, arrow keys and tab completion are not implemented in the
  REPL's line editing.

## Phase 5: synthesis handoff

Commit `82e4f79` (phase 7 adds the USB domain to the same files).

Built: `make_hammer_design.py --top mpy_soc` writes `io_clk` (20 ns),
asynchronous to `core_clk`, every crossing bounded by `set_max_delay` to
the faster period, the island's pads timed against `io_clk` and the
synchronized pins untimed; the island's SRAMs as `fakeram_d4096_w32` and
`fakeram_d2048_w32`; `mpy_dc_unit.py` takes the island and puts the sky130
ICG cell in place of CVE2's behavioral clock gate; `convert_rtl.sh` and
`sweep.sh` cover the island. The generated `mpy_soc` unit elaborates as
one file in yosys-slang.

Island Fmax in the open flow: 18.93 ns worst path (phase 4 RTL), about
53 MHz against the 50 MHz `io_clk`; 19.96 ns with phase 7's USB decode.

Phase 5 changes no file the simulator, the firmware or the STA flow
reads, so its G1 to G4 are phase 4's.

Not done (tools not available here): the plan's Genus run of `mpy_soc`
at 10 ns with the island in; sv2v regeneration of `converted/mpy_core.v`
and `converted/mpy_soc.v` (a downloaded sv2v binary could not be run),
which the synthesis README marks stale.

## Phase 6: measurements

Commits `f313e32` (hooks and `io_measure.py`) and the measurements
commit. The table is in `upycore/docs/mpy_io_core.md` (Measurements),
the data in `upycore/docs/mpy_io_core_measurements.json`: GPIO toggles at
94,000 to 129,000 changes/s from Python; pin edge to the first opcode of
a soft `Pin.irq` handler 56.4 / 58.2 / 62.7 µs (min / mean / max over
1,000 edges, none missed), 7.3 µs of it the I/O core's; a 1 kHz Timer's
period σ 1.65 µs; UART transmit at line rate to 3 Mbaud; UART receive
complete at 115200 baud but losing bytes from 460800 (the hart drains
about 10 KB/s). Island power was not computed: there is no power engine
here; the SAIF files for Genus or Joules are produced. Phase 6 changes
only the bench and tools, so its G1 to G4 are phase 4's and phase 7's.


## Phase 7: USB

Commit `ada8605`; the gates ran on it, G3 rerun after the STA flow fix in the next commit.

Built: the no2usb SIE on its own 48 MHz `usb_clk` behind a
request/answer-toggle bridge from io_clk (`iocore_usb`); generic
replacements for its iCE40 primitives (256 × 16 one-read-one-write RAMs
behind BaseJump's `bsg_mem_1r1w_sync_mask_write_bit`, the microcode as a
ROM of constants, `SB_IO` as flops and a pad wrapper); TinyUSB CDC ACM in
the firmware with the epic branch's ported driver; the USB console
(`+CONSOLE=usb`); the epic branch's USB host model in the bench; the
`usb` area (`usb_loopback` 4 KB, `usb_ctrl_c`, `usb_suspend`,
`usb_repl_raw`) and the console area over USB (`con_print_usb`,
`con_input_usb`, `repl_friendly_usb`, the UART goldens); the
`iocore_usb` crossing bench (12 ratios, 33,714 checks); `usb_clk` and
the sixteen macros in the Hammer constraints; the I/O areas and the
RISC-V toolchain in CI.

| Gate | Result |
| --- | --- |
| G1 | PASS: 23 of 23 workloads at +0.000 % |
| G2 | PASS: 543 of 543 pass; 505 with the baseline's cycles, 0 moved, 38 new |
| G3 | PASS: `mpy_core` 577 of 578 matched, none slower by > 0.1 (27.389 → 27.389 ns); `mpy_soc` 1,104 of 1,105 matched, none slower by > 0.1 beyond the `hvalid` noise. The first run stopped on a `$scopeinfo` annotation the island stub's new inout ports left in the netlist; the STA flow now deletes those (they carry no logic) and the rerun on the same RTL passed |
| G4 | PASS: 505 identical, 0 differ, 38 not in both trees |
| G5 | Logic PASS: island with USB 197,782 µm² + `mpy_iobr` 180,577 µm² = 378,359 of 450,000 (the USB block alone 23,570 µm², 565 flops). SRAM **over**: 28.5 KB against 28 KB (16 KB code, 8 KB data, 4.5 KB of USB RAMs) |


Unit benches: 37 of 37 (adds `iocore_usb`, the usb_clk crossing at twelve ratios).

Clock-ratio sweep on the final tree (`--sim-arg +IO_CLK_NS=10` and
`6.667`, every I/O area): all pass at hart/1; at hart × 1.5
`io/sleep_accuracy` failed, a 20 ms sleep 150 µs long or more. The
firmware truncated the microsecond divider (`hz / 1000000 - 1`): at the
bench's 149,992,500 Hz a microsecond was 149 io_clk cycles, 0.7 % short,
so `ticks_us` ran fast against the hart's wait. It now rounds; with that
`sleep_accuracy`, `ticks` and `blink` pass at all three ratios, every I/O
area passes again at the default io_clk (io 10, irq 8, system 7, console
9, usb 4) and the io area at hart × 1.5. Every
I/O area also passes compiled by uPy2 (`--compiler mpyc`, as CI runs
them): io 10, irq 8, system 7, console 9, usb 4.

Deviations and open items:

- G5's SRAM budget: 28.5 KB against the 28 KB set in phase 0. The
  endpoint buffers are 4 KB as budgeted; the SIE's 512-byte endpoint
  status table was not in that budget.
- Console output waits for the host (DTR) for at most 2 s before it is
  dropped; MicroPython's CDC console drops it from the start. The tests
  rely on the wait, so a program's first output is seen.
- The SIE's `usb_clk` paths are not timed in the open flow (no model for
  the PHY's negative-edge input register); the Genus run with the USB
  domain was not run here. Whether the class `bsg_fakeram` generator
  takes the `1r1w` family is not checked.
- CI changes (the Docker image's RISC-V toolchain, the I/O areas in the
  matrix) were not run: there is no Docker or CI here. The image's
  Verilator is Debian's 5.032; this work used 5.038.
