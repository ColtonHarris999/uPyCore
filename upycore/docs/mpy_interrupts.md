# Interrupts on the MicroPython hart

Status: as built. The plan is
[`planning/interrupts_io_plan.md`](../../planning/interrupts_io_plan.md)
(revision 1); this page describes the hardware and firmware that exist.
Register rules stay in [`mpy_peripherals.md`](mpy_peripherals.md) and
the SRAM windows in [`mpy_memory_map.md`](mpy_memory_map.md). Pin
functions are MicroPython v1.29.0.

## Pieces

| Piece | Where |
| --- | --- |
| Sources, status, enable, hard, GIE, the schedule ring, the handler flops | `upycore/rtl/mpy_irq.sv`, inside `mpy_periph` |
| Boundary poll, mirror, callback entry and return, heap lock, idle | `upycore/rtl/mpy_core.sv` (`S_IRQ_*`, `S_IDLE`, `S_AL`) |
| Callback trampoline and the uncaught path | `upycore/firmware/boot.py` (`_irq_call`, `_irq_uncaught`) |
| `machine`, `time`, per-pin dispatch | `upycore/firmware/machine.py` |
| `micropython.schedule`, `heap_lock`, `heap_unlock`, `kbd_intr` | `upycore/firmware/modules.py` |

## Boundaries and soft points

`S_DEC` sets `need_poll` when it hands an opcode to `S_EXEC`, and reset
starts with it set. The next `S_FETCH` does any register-ring spill or
reload first, then runs the poll instead of decoding:

1. `S_IRQ_POLL`: `irq_boundary` is high for this clock, and `irq_jump`
   too when the opcode that ended was a soft point. `fire` and
   `kbd_raise` answer on this clock.
2. `S_IRQ_TAKE`: mirror if `mirror_dirty`, then raise
   `KeyboardInterrupt` if `kbd_raise` was seen, else call the callback if
   `fire` rose, else decode.

The cost with nothing to do is two clocks per opcode.

A soft point is the retirement of `JUMP`, `POP_JUMP_IF_TRUE`,
`POP_JUMP_IF_FALSE`, `JUMP_IF_TRUE_OR_POP`, `JUMP_IF_FALSE_OR_POP`,
`UNWIND_JUMP` (its final jump), or `POP_EXCEPT_JUMP`, taken or not, in a
frame that is not firmware. Firmware stands in for the C runtime, so a
jump inside `print` or `machine` is not a soft point and a soft callback
never runs half-way through one. Hard callbacks are taken at any
boundary, firmware frames included. Firmware loops that wait a long time
(`time.sleep_ms`) call `_pending()`, which is one soft point, the way the
C ports call `mp_handle_pending`.

A path that re-runs the opcode it is in (`pc <= op_pc`: the truth,
get-iter, and replace continuations) clears `need_poll`, because it
carries state that is not in the frame (`ovr`). So does the generator
resume that defers a throw into the next `YIELD_FROM` (`inj`).

## Calling a callback

`S_IRQ_TAKE` calls the `_irq_call(fn, arg)` hook with return kind
`RK_IRQ`. The call path is the ordinary one: `S_CALL` spills the
interrupted frame, whose header already holds everything a resume needs.
`_irq_call` is a firmware frame (no traceback line) whose body is
`fn(arg)`, so a function, a bound method, a native, or a type all work,
and an exception from any of them stops in that frame.

On return, `S_DELIVER`'s `RK_IRQ` arm pulses `done` and resumes the
interrupted frame at `S_FETCH`. If the callback was taken from `_idle`
it polls once more; from `_pending` it returns `None` to the native's
caller. No callback starts while `fire` is high: there is no nesting.

The tags of `fn` and `arg` travel from the handler flops (or the ring
slot) through `fire_fn_tag` / `fire_arg_tag` into the call.

## Hard, soft, and schedule

- **Hard** sources are taken at any boundary. `fire_hard` holds
  `heap_locked` until `done`. `S_AL` sees the lock and does not collect:
  a soft allocation (a traceback entry) fails quietly, any other raises
  `MemoryError: memory allocation failed, heap is locked` through the
  emergency object.
- **Soft** sources join the ring at a soft point and run one per soft
  point, with the heap unlocked.
- **`micropython.schedule(fn, arg)`** is the `_sched` native: one
  `sched_push` with both tags, then `sched_full` a clock later. The ninth
  push with none popped raises `RuntimeError: schedule queue full`.
- **`heap_lock()` / `heap_unlock()`** are a 16-bit depth in the core that
  wraps like `gc_lock_depth` in v1.29.0; `heap_unlock` returns the new
  depth. The hard-callback lock ORs with it and is not part of the depth.
- **`machine.disable_irq()`** is `_irqoff`, which reads and clears
  `IRQ_GIE` inside one native, so no boundary falls between the two
  accesses. `enable_irq(state)` writes bit 0 back.

## Keyboard interrupt

`KBD` (source 6) has no handler. At a soft point with no hard callback
running, an armed `KBD` pulses `kbd_raise` instead of the soft steps,
and the core raises `KeyboardInterrupt` in the running frame. A soft
callback can be interrupted; its trampoline catches it like any other
exception. The UART raises `KBD` for the `UART_KBD` character, which is
not queued; the coprocessor's doorbell raises it directly.
`micropython.kbd_intr(c)` writes the character and the `KBD` enable bit;
`kbd_intr(-1)` clears both.

## An exception that escapes a callback

`S_RAISE` unwinds callback frames as usual. When the frame it would
leave is the `RK_IRQ` trampoline, it fills the interrupted frame instead
of re-raising there, stores the exception at `SR_IRQ_EXC`, and calls
`_irq_uncaught(hard, src)`, itself with return kind `RK_IRQ`:

1. Hard: write `Uncaught exception in IRQ callback handler` to stderr,
   clear the handler slot and the source's `IRQ_ENABLE` bit
   (`mp_irq_handler`, `shared/runtime/mpirq.c`). None of this allocates;
   the heap is still locked.
2. `_irq_done()` pulses `done` and unlocks the heap.
3. Print the traceback: stderr for hard, stdout for soft and schedule
   callbacks (`mp_call_function_1_protected`). A soft source stays armed.
4. Return; the resume rules above apply.

A hard callback's traceback has no frame lines, because the entries
could not be allocated while the heap was locked. An exception raised by
`_irq_uncaught` itself is dropped.

## GC roots

The flop file is the delivery copy. Before the next opcode after a
handler write, a push, or a pop, and before any collection, the core
writes every ring slot and handler slot, tagged, into the windows at
`ABI_SCHED_BASE` and `ABI_HANDLER_BASE`, which `gc_root1` scans. That
is at most 32 tagged stores. A slot outside `[head, tail)` is written as
the empty word, and an `INT` argument is never followed, whatever its
payload.

## Idle

`machine.idle()` is the `_idle` native. It polls (jump low, so only hard
callbacks run), then parks in `S_IDLE` until `wake`: a tick, an accepted
UART byte, a GPIO pin match, or any other source event, enabled or not.
Then it polls again and returns `None`. A hard callback taken there
returns to idle, which polls once more. A soft callback runs at the
caller's next soft point. No opcode retires while parked.

`time.sleep_ms(n)` idles until `TICKS` moves, `n` times, with a
`_pending()` soft point after each tick.

## Latency

A hard callback waits for the opcode in flight, including any collection
that opcode started (GC is not preempted), plus two poll clocks, plus a
dirty mirror (at most 32 stores), plus the call into `_irq_call` and the
callback's own call. The final report gives the measured worst case.

## Python surface

| Call | Effect |
| --- | --- |
| `Pin(id, mode=-1, pull=-1, value=None)` | `id` 0..15. `Pin.OUT` sets `GPIO_OE`, `Pin.IN` clears it, `PULL_UP` / `PULL_DOWN` set the pull bits |
| `Pin.value()`, `on`, `off`, `toggle`, `__call__` | `GPIO_IN` for an input, `GPIO_OUT` for an output; writes are read-modify-write under `disable_irq` |
| `Pin.irq(handler=None, trigger=3, hard=False)` | `IRQ_RISING` 1, `IRQ_FALLING` 2. The pin's entry in the dispatch table, its `GPIO_EDGE` bits, the GPIO slot (`_gpio_dispatch`), `IRQ_HARD` when any armed pin is hard, `IRQ_ENABLE` while any is armed |
| `Timer(0).init(mode=PERIODIC, freq=-1, period=-1, callback=None, hard=True)` | `period` in ticks (ms). `ONE_SHOT` stops the compare before the callback. `period=0` arms nothing. Other ids raise `ValueError` |
| `UART(0, baudrate=None)` | `baudrate` writes `UART_BAUD = freq() // baudrate`; `write` waits on a full TX FIFO; `read`, `readinto`, `any`; `irq(handler, trigger=IRQ_RX, hard=False)` |
| `mem8`, `mem16`, `mem32` | `_peek8` / `_peek32` / `_poke8` / `_poke32`; misaligned raises `ValueError` |
| `disable_irq`, `enable_irq`, `idle`, `freq` | As above; `freq()` reads `SYS_FREQ` |
| `time.ticks_ms`, `ticks_us`, `ticks_cpu`, `ticks_diff`, `ticks_add` | `TICKS` and the cycle counter, wrapping at 2^30 |
| `time.sleep`, `sleep_ms`, `sleep_us` | Idle on ticks |

The GPIO dispatcher reads `GPIO_STATUS`, clears the bits it saw, and
calls each pin's handler with its `Pin`, lowest pin first. In a hard
dispatch (`IRQ_ACTIVE`), a soft pin's handler goes through
`micropython.schedule` instead.

## Tests

The `io` area of `upycore/programs/hw_tests.toml`. Timing traces
(`blink`, `blink_slow`, `blink_off`, `echo_fifo`, `echo_overrun`,
`debounce`) are checked against `mpy_periph_model.py` through the
`MPY_IO` summary `tb_mpy_soc` prints; `+MAX_TICKS` ends those runs with a
trace pass. `sched_*`, `heap_lock`, and `sleep_ticks` are compared with
the unix oracle.
