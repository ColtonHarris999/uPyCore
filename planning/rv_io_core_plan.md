# Board I/O through an RV32 I/O core

Status: **plan, for review.** Nothing here is built on `main`. Branch:
`rv-io-core`, from `main` `c895f2d`.

Goal: uPyCore behaves like a MicroPython microcontroller board: `machine.Pin`,
`UART`, `Timer`, `PWM`, `SPI`, `I2C`, `ADC`, `WDT`, pin and timer callbacks,
`micropython.schedule`, Ctrl-C, `time.sleep_ms`/`ticks_ms`, and a UART
console with the REPL. Board I/O goes through a small RV32 core (the **I/O
core**) that owns every peripheral. The hart reaches it through one
memory-mapped bridge.

The overriding constraint: **uPyCore's performance stays where it is.** A
program that does no I/O must run in exactly the same number of cycles as it
does on `main`, from the same image bytes, and the hart's 10 ns timing work
must not be undone. Every phase below has a gate that checks this (§8).

## 1. Where things stand

- `main` has no board I/O. The SoC's ports are the console byte stream
  (stores to the simulator page at `0xE000_0000`), SPI NAND boot, and
  halt/debug outputs (`upycore/docs/mpy_peripherals.md`: "Not integrated").
  `mpy_mem` treats the MMIO window `0x4000_0000` as a bus fault.
- `mpy_periph.sv` and `mpy_irq.sv` on `main` are a hart-side peripheral block
  (UART, GPIO, timer, IRQ registers, an 8-deep schedule ring), unit-tested by
  `tb_mpy_periph` and not instantiated.
- `origin/claude/epic-dirac-58oxzv` (Oct 26–27, 19 commits, about 11.8k lines,
  unmerged; `main` has moved 120 commits since) built a full prototype:
  - the peripherals on the hart's MMIO window: UART with FIFOs and 8N1, GPIO
    with direction/pulls/edges, ticks, PWM, pin mux, SPI, I2C, watchdog, ADC
    interface;
  - interrupt delivery in the core: a poll at every opcode boundary
    (`S_IRQ_POLL`/`S_IRQ_TAKE`), handler and ring flops mirrored into SRAM
    as GC roots;
  - `machine`/`time` in firmware, a UART console and REPL;
  - a CVE2 RV32EMC coprocessor (TinyUSB on no2usb, 48 MHz) behind a mailbox
    (`mpy_mbox`, two 16-word dual-clock FIFOs) and a 4 KB dual-clock shared
    SRAM, used only for USB.

  Its own docs report the interrupt poll costs **2 clocks per opcode** when
  nothing is pending, applied to every program. That cost, and the amount of
  new hart-side logic, are what this plan avoids.

## 2. Architecture

```
            hart clock (10 ns target)          |        io_clk (independent)
                                               |
 mpy_core ── core port skid (mpy_soc) ─┬─ mpy_mem (SRAM, image)
                                       ├─ sim page (console, halt) — unchanged
                                       └─ IO bridge (0x4000_0000 window)
                                            ├─ CMD FIFO ─────────────┼──▶ io_core (RV32)
                                            ├─ RSP FIFO ◀────────────┼──    ├─ code/data SRAM
                                            ├─ EVT register ◀─ sync ─┼──    ├─ timer, ticks
                                            └─ state page (dual-port)┼──    ├─ UART, GPIO, PWM, pin mux
               evt_pend (flop) ──▶ mpy_core                          |      ├─ SPI, I2C, ADC, WDT
                                                                     |      └─ (later) USB SIE
```

The rules that keep the hart fast:

1. **No new state on the opcode path.** The hart checks for I/O events only at
   soft points (§5), using one flop that is already valid when the check runs.
   When nothing is pending, no opcode takes an extra cycle.
2. **No new logic in the core's critical paths.** The window decode happens in
   `mpy_soc`, on the core-port skid, exactly like the simulator page. `mpy_mem`
   (the SRAM arbiter the 10 ns work tuned) does not change. `mpy_core` gains
   one input flop, one term in `S_FETCH`, and a hook call.
3. **A separate clock domain.** The I/O core and its peripherals run on
   `io_clk`. Every signal crossing to the hart goes through a dual-clock FIFO,
   a two-flop synchronizer, or the dual-port state page. The I/O island never
   appears in a hart-domain timing path, and it closes timing on its own.
4. **Images unchanged for programs without I/O.** `machine`, `time` and the
   I/O half of `micropython` are frozen runtime modules (`RUNTIME_MODULES`,
   `upycore/runtime`), linked only into images that import them. The heap
   size, GC behavior and every cycle count of other programs stay put.
5. **The I/O core's firmware lives in its own SRAM.** `mpy_boot` loads it from
   the NAND image before releasing the hart, so it takes no hart SRAM or heap.
   Boot takes longer, but the hart's cycle counter starts at its first
   instruction.

## 3. The I/O island

### 3.1 Core

**Recommendation: CVE2 (RV32EMC).** The epic branch already wraps it
(`coproc/rtl/coproc_top.sv`), and its firmware layout (`crt0.S`, linker
script, toolchain notes, `bin2hex.py`) works.

**Alternative: Hazard3.** The team already synthesizes Hazard3 in the class
flow as the benchmark baseline (`upycore/synth/hammer/README.md`), so its
Genus behavior is known.

**Review decision D1.** Phase 0 measures both in the open estimate flow and
picks one. Whichever is chosen:

| Item | Requirement |
| --- | --- |
| ISA | RV32IMC or RV32EMC, no FPU. Machine mode only |
| Interrupts | A local interrupt controller: timer, each peripheral, the bridge's CMD-not-empty. `wfi` gates the core when idle |
| Code SRAM | 8 KB (board I/O); 16 KB if USB lands (§7) |
| Data SRAM | 4 KB (board I/O); 8 KB with USB |
| Bus | One simple valid/ready bus; peripherals are word-addressed slaves |
| Clock | `io_clk`, set by a strap or a divider; simulation default 50 MHz |

### 3.2 Peripherals (on the I/O core's bus, not the hart's)

Port the epic branch's blocks and their register rules as RV-bus slaves:
`mpy_periph` (UART, GPIO, timer, ticks), `mpy_pwm`, `mpy_pinmux`, `mpy_spi`,
`mpy_i2c`, `mpy_adc`, `mpy_wdt`. The hart never sees these registers; the
register tables move from `mpy_peripherals.md` to a new
`upycore/docs/mpy_io_core.md`. The hart-side `mpy_irq` and its flop ring are
not used. The schedule ring and handler table move into hart firmware (§5).

`mpy_sys` (system reset, watchdog reset) resets the hart domain only. The I/O
core keeps running across `machine.soft_reset()`, as a separate I/O chip
would.

### 3.3 I/O core firmware (C, `iocore/sw`)

One event loop plus interrupt handlers:

- **Commands:** execute each one in the CMD FIFO (§4.2) and answer
  synchronous ones in the RSP FIFO.
- **State page:** keep the mirror in §4.3 current: pin levels, `ticks_ms`,
  `ticks_us`, UART RX level, timer counts.
- **UART:** buffer RX in a 256-byte ring so the hart never loses a byte, and
  drain TX from a ring the hart fills by command. When the Ctrl-C character
  arrives and is armed, raise the `KBD` event instead of buffering it.
- **Events:** turn pin edges, timer matches, UART RX and WDT warnings into
  event bits (§4.4).
- **Idle:** `wfi` when there is nothing to do.

The build is `make -C iocore/sw` with the riscv GCC and picolibc packages the
epic branch documents (`coproc/sw/TOOLCHAIN.md`). The image goes into the
boot stream (§4.5). Size gate: board I/O firmware ≤ 6 KB code, ≤ 2 KB data.

## 4. The hart-side bridge (`mpy_iobr.sv`, in `mpy_soc`)

### 4.1 Steering

`mpy_soc` already decodes `c_sim` from the core's request and answers the
simulator page itself, ordered behind outstanding memory acks (`c_out`). Add
`c_io` beside it with the same handling:

- `c_io` is MMIO-region decode of `c_addr`. It is registered into the skid with
  `k_sim`. `io_go = p_req && p_io && c_out == 0`.
- Loads answer one cycle later, like `sim_rdata`. Stores are posted.
- A misaligned access, or an offset outside the implemented registers, answers
  with a bus fault through the same fault path a memory access uses.
- `mpy_mem` changes only to stop granting the MMIO window: `mpy_soc` never
  presents it there.
- Fetch, the collector and the copy engine never address the window. The
  shared state page is untagged words: never a GC root, never heap.

### 4.2 Registers (window offsets, words only)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x000` | `CMD` | A store pushes a word to the CMD FIFO (32 deep). A store while full holds the core (the skid's `m_busy_i`) rather than dropping |
| `0x004` | `RSP` | A load pops the RSP FIFO (16 deep); bit 31 of `STATUS` says it was valid |
| `0x008` | `STATUS` | CMD level, RSP level, CMD full, RSP not empty |
| `0x00C` | `EVT` | Pending event bits (§4.4). A load reads them; a store of 1s clears those bits |
| `0x010` | `EVT_EN` | Bits that may set `evt_pend` |
| `0x014` | `EVT_SET` | A store of 1s sets those bits from the hart (`micropython.schedule`, the soft event) |
| `0x018` | `EVT_MASK` | Bit 0 masks delivery while a callback runs. Firmware sets it in `_irq_dispatch` and clears it on return |
| `0x01C` | `IOC_CTRL` | I/O core run/hold and the firmware-loaded flag; read-only to programs |
| `0x800`–`0xFFF` | State page | 2 KB dual-port RAM. The hart reads and writes words; the I/O core owns the layout in §4.3 |

Word access only, as in the epic branch's mailbox. A CMD word is a channel
(bits 31:24) and a payload (bits 23:0). Multi-word commands state their length
in the first word.

### 4.3 State page layout (I/O core writes, hart reads)

Pin input levels and edge flags, `ticks_ms`, `ticks_us` (low 30 bits),
`ticks_cpu` of the I/O core, UART RX level and TX space, a timer-callback
counter per timer, an ADC result per channel, the console mode, and a version
word. Reading one of these is a single load: about 2 hart cycles, with no
round trip to the I/O core. That keeps `Pin.value()`, `ticks_ms()` and
`UART.any()` cheap.

### 4.4 Events and `evt_pend`

`EVT` has 32 bits, set by the I/O core through a toggle synchronizer per bit
group (or a small dual-clock FIFO of set-masks):

| Bits | Use |
| --- | --- |
| 0 | `SOFT` (`micropython.schedule`) |
| 1 | `KBD` (Ctrl-C) |
| 2 | `UART0_RX` |
| 3 | `TIMER` (any timer; the counters are in the state page) |
| 4 | `PIN` (any pin edge; flags in the state page) |
| 5 | `WDT` warning |
| 6–15 | the other peripherals |
| 16–31 | reserved |

`evt_pend` is a flop:
`|(EVT & EVT_EN) && !EVT_MASK[0]`, registered on the hart clock. It is the
only signal the I/O work adds to `mpy_core`.

### 4.5 Boot

The boot stream (`upycore/docs/mpy_boot.md`) gains an optional section after
the image: magic `IOCB`, a word count, then the I/O core's code and data
images. `mpy_boot` writes them into the I/O core's SRAMs through a load port,
then releases the I/O core's reset. No section means the I/O core stays in
reset, `IOC_CTRL` reads "not loaded", and `machine` raises `OSError(ENODEV)`.
The SRAM clear, image load and GC table clear are unchanged, so a stream
without the section is the boot every existing test runs.

## 5. Events on the hart

### 5.1 Core change (the only one)

- **Soft points.** As in MicroPython's `py/vm.c` pending check: retiring
  `JUMP`, `POP_JUMP_IF_TRUE/FALSE`, `JUMP_IF_TRUE/FALSE_OR_POP`,
  `UNWIND_JUMP`, `POP_EXCEPT_JUMP`, taken or not, in a frame that is not
  firmware. Firmware stands in for the C runtime, so a callback never runs
  halfway through `print`.
- **`soft_pt`.** A flop set when such an opcode retires and cleared in
  `S_DEC`. `JUMP` (`8'h42`) ends in `st <= S_FETCH`. The conditional jumps
  retire through `S_TR`/`S_JT`: confirm that each path reaches `S_FETCH`, not
  `go_next`. A path that skips `S_FETCH` gets the check in `S_DEC`'s existing
  stop arm instead.
- **The check.** In `S_FETCH`, after the existing fault, spill and reload
  arms, add one arm: `soft_pt && evt_pend` → call the firmware hook
  `_irq_dispatch()`. Both terms are flops. With nothing pending the arm is
  never taken, so cycle counts do not move.
- **The call.** It goes through the ordinary call path (`S_CALL` spills the
  interrupted frame) with a return kind that discards the result and
  resumes at `S_FETCH` with `pc` unchanged. Check `ABI_RK_DISCARD` first; if
  its semantics differ, add `ABI_RK_IRQ`. The hook frame is a firmware
  frame, so it adds no traceback line.
- **`machine.idle()`/`time.sleep_ms()`.** A new native, `_wfe`, holds the core
  in a wait state until `evt_pend`, a timeout in hart cycles, or a state-page
  tick change. It is one microcode state off the opcode path.
- **Heap lock.** `heap_lock()`/`heap_unlock()` become a core depth counter that
  `S_AL` checks (one flop compare on the allocation path, which is not
  timing-critical). The lock raises
  `MemoryError: memory allocation failed, heap is locked` through the
  emergency object. Phase 3 measures it, and it can be dropped if it costs
  cycles anywhere.

Nothing else in the core changes: no per-opcode poll, no handler flops, no GC
mirror.

### 5.2 Firmware (`upycore/runtime/machine.py`, `time.py`; hooks in `boot.py`)

`_irq_dispatch()` (in `boot.py`):

1. Sets `EVT_MASK`.
2. Reads and clears `EVT`. For `KBD`, raises `KeyboardInterrupt`; it
   propagates into the interrupted frame through the normal unwinder, since
   the hook frame is a callee at the boundary `pc`.
3. For each other set bit, calls that source's handlers from a Python table
   (pins and timers read their flags or counters from the state page). Each
   call is wrapped the way MicroPython's `mp_call_function_1_protected` is:
   an exception prints its traceback and the source stays armed.
4. Pops up to one `micropython.schedule` entry per call from an 8-deep list
   (`RuntimeError: schedule queue full` on the ninth).
5. Clears `EVT_MASK`. Pending bits re-raise `evt_pend` for the next soft point.

The handler table and the schedule list are ordinary heap objects reachable
from the system roots, so the collector needs no mirror.

- **`hard=True`:** v1 delivers it at the next soft point with the heap locked.
  It is not delivered at an arbitrary boundary; **review decision D2.** The
  I/O core covers the latency-critical part (debounce, capture, UART
  buffering) in its own interrupt handlers.
- **`micropython.schedule`:** appends and stores `EVT_SET = SOFT`. Today's
  stub calls the function at once; it becomes a real deferral. Check the
  existing hardware tests that use it: their output must not change.

### 5.3 The `machine` API (MicroPython v1.29.0 signatures)

| API | Implementation |
| --- | --- |
| `Pin(id, mode, pull, value)`, `.value()`, `.on/off/toggle`, `.irq()` | Configure and write through CMD; `value()` reads the state page; `irq()` registers a handler and enables the edge on the I/O core |
| `Timer(id, mode, period, freq, callback)`, `.deinit()` | CMD to the I/O core's timer; callbacks via the `TIMER` event |
| `UART(id, baudrate, …)`, `.write/.read/.readinto/.readline/.any/.irq()` | Bulk data through CMD/RSP words, 3 bytes a word; `any()` from the state page |
| `PWM`, `SPI`, `I2C`, `ADC`, `WDT` | Each a CMD request and RSP answer; SPI and I2C transfers up to 64 bytes a request |
| `mem32` | The window only (the bridge registers and the state page) |
| `disable_irq()`/`enable_irq(s)` | `EVT_MASK` bit 1 |
| `idle()`, `freq()`, `reset()`, `soft_reset()`, `unique_id()`, `reset_cause()` | `_wfe`; constant; `mpy_sys` |
| `time.sleep_ms/us`, `ticks_ms/us/cpu/add/diff` | State page and `_wfe`; `ticks_cpu` stays the hart cycle counter |

### 5.4 Console

The default console stays the simulator page, so every existing golden file
stays valid. A boot strap (`+CONSOLE=uart` in the bench, a pin on the chip)
sends `sys.stdout`/`sys.stdin` through the I/O core's UART, which enables the
REPL and raw REPL (`mpremote`). `_wr` keeps its fast path; only the console
redirect checks the strap.

## 6. Reuse from the epic branch

| Take (adapt to current `main`) | Leave |
| --- | --- |
| `mpy_async_fifo.sv`, `mpy_shared_ram.sv` (state page), the `mpy_mbox` FIFO logic | `S_IRQ_POLL`/`S_IRQ_TAKE` and the per-opcode `need_poll` |
| `coproc_top.sv` bus decode and SRAMs, `crt0.S`, linker script, `bin2hex.py`, `TOOLCHAIN.md` | Hart-side `mpy_irq` flops, the handler mirror, `fire_*_tag` sidebands |
| `mpy_periph` UART/GPIO/timer/ticks, `mpy_pwm`, `mpy_pinmux`, `mpy_spi`, `mpy_i2c`, `mpy_adc`, `mpy_wdt`, `mpy_sys`, re-homed on the I/O bus | Peripheral registers in the hart's window |
| Bench models: `tb_i2c_target`, `tb_spi_flash`, `tb_adc_model`, the UART terminal; later `tb_usb_host` | Console routing inside the core |
| `machine.py`/`time.py` structure and the hardware tests in its `io`, `irq` and `system` areas (re-goldened where messages move) | |

Cherry-picking will not apply: `mpy_core` and `mpy_soc` have changed too much
since Oct 26. Copy files and port them by hand. Keep the epic branch as the
reference.

## 7. Phases

Each phase is one or more commits on `rv-io-core`. It ends with the gates in
§8 and a progress note in `planning/rv_io_core_progress.md`. Do not merge to
`main` before review.

| Phase | Work | Done when |
| --- | --- | --- |
| **0. Island spike** | Pick the core (D1) from open-flow area and timing of CVE2 and Hazard3 islands with 8+4 KB SRAMs. Standalone `iocore_top` with SRAMs, timer, UART; `tb_iocore` runs a hello firmware. Toolchain in the dev container | `tb_iocore` prints over its UART model; area and timing table in the progress note |
| **1. Bridge and boot** | `mpy_iobr` in `mpy_soc` (§4.1–4.4), CDC, the boot-stream section and I/O core load, the `_poke32` native (append-only id). No `mpy_core` change. Loopback firmware echoes CMD to RSP | A hart program round-trips 1,000 words; a misaligned window access faults; G1–G4 pass |
| **2. Polled board I/O** | Peripherals on the I/O bus; I/O core firmware for GPIO, UART, timers, ticks; state page; `machine`/`time` as runtime modules (polling only); UART console strap; `io` hardware-test area | Blink, UART echo at 115200 8N1, `sleep_ms` accuracy and `ticks_diff` tests pass; G1–G4 |
| **3. Events** | The §5.1 core change, `_irq_dispatch`, `Pin.irq`, `Timer` callbacks, `UART.irq`, real `micropython.schedule`, `heap_lock`, Ctrl-C, uncaught-callback output; `irq` area | MicroPython-matching outputs for callback tests; **G1 shows 0 cycles on every existing workload**; G3 shows no `mpy_core` group slower |
| **4. Remaining peripherals and REPL** | PWM, SPI, I2C, ADC, WDT, pin mux, `reset`; friendly and raw REPL on the UART console; `system` area | `mpremote`-style raw REPL session test passes |
| **5. Synthesis handoff** | Two-clock constraints in `make_hammer_design.py` (`io_clk` asynchronous to `core_clk`; FIFO pointer paths constrained); SRAM macros for the island; `convert_rtl.sh` covers the island; `check_syn.py` counts | Genus at 10 ns on `core_clk` with the island in; the island's own Fmax recorded |
| **6. Measurements for the paper** | Python GPIO toggle rate; pin-edge to first callback bytecode latency (min/mean/max over 1,000 edges); UART throughput; timer callback jitter; island idle and active power from SAIF | Table in `upycore/docs/mpy_io_core.md` |
| **7. USB (optional, D3)** | The epic branch's TinyUSB CDC on the I/O core: SIE on a 48 MHz clock, ASIC replacements for no2usb's iCE40 primitives, `usb` test area | Enumeration and raw REPL over USB in simulation |

## 8. Performance gates (every phase)

Baseline: `main` `c895f2d`. Build its simulator once and keep the binary.

| Gate | Check | Pass |
| --- | --- | --- |
| **G1 cycles** | `upycore/tools/clock_bench.py --before <c895f2d sim> --after <branch sim>` (AES, Fannkuch, the timing loops, pystone, every program in `upycore/programs/bench`) | **0.000 %** on every workload |
| **G2 suite** | `hw_tests.py --area all` on both simulators. Diff the per-test `cycles=` values | All pass. Identical cycles for every test that does not import `machine`/`time` or use the window |
| **G3 timing** | `upycore/tools/sta/run.py` (unmapped, deterministic) on `mpy_core` and `mpy_soc`, branch against baseline, `--compare` | No register group slower by more than 0.1 in the hart domain. The island is timed in its own run |
| **G4 image** | Link every hardware-suite program on both trees | Byte-identical images for programs that do not import the I/O modules (so heap size and GC behavior match) |
| **G5 island** | Open-flow area of the island (excluding SRAM macros) and its SRAM bytes | Within the budget set in phase 0, which reviewers approve |

If a gate fails, the change does not land. Fix it or bring it back to review.
A phase may not trade hart cycles for I/O features.

## 9. Verification

- Unit benches: `tb_iocore`, `tb_mpy_iobr` (randomized CMD/RSP/EVT traffic
  across the clock ratio range 1:3 to 3:1, FIFO full/empty edges, reset of one
  side), plus the ported peripheral benches.
- Hardware suite areas: `io` (polled), `irq` (callbacks, schedule, Ctrl-C,
  heap lock), `system` (console, REPL, reset, WDT). The goldens are written
  by hand where the unix oracle has no `machine`, as the epic branch did. Each
  states the MicroPython source it follows.
- Clock-ratio sweep: run `io` and `irq` at `io_clk` = hart/2, hart/1 and
  hart×1.5 in simulation. Outputs must match; only latencies may change.
- CI: add the I/O core firmware build and the new areas to
  `.github/workflows/all-tests.yml` behind the existing Docker image.

## 10. Docs to write or change

- New `upycore/docs/mpy_io_core.md`: the island, its memory map, the
  peripheral registers, firmware structure, the command protocol, events,
  boot, and measurements.
- `mpy_peripherals.md`: replace with a pointer to `mpy_io_core.md` and a short
  history note.
- `mpy_memory_map.md`: the bridge window and state page.
- `mpy_boot.md`: the `IOCB` section.
- `README.md`, `synth/hammer/README.md`, `planning/README.md`.

## 11. Decisions for review

| # | Question | Recommendation |
| --- | --- | --- |
| D1 | I/O core: CVE2 or Hazard3 | Decide in phase 0 on area and timing. CVE2 if equal (more reuse from the epic branch) |
| D2 | `hard=True` callbacks | Deliver at soft points with the heap locked. Any-boundary delivery would need the per-opcode check this plan exists to avoid |
| D3 | USB in scope | After board I/O; optional phase 7 |
| D4 | `io_clk` | Independent clock with full CDC (the hart's timing stays untouched). A same-clock option only if phase 0 shows the island meets 10 ns with margin |
| D5 | Reads through the state page versus RPC | State page for everything polled; RPC only for transfers |
| D6 | Console default | Simulator page (goldens unchanged); UART by strap |
