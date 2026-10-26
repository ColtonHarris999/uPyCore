# Interrupts and IO

Status: **plan, revised once.** The register model and the standalone
peripheral block are already built. This file is how they become basic
microcontroller behavior on the hart: memory-mapped GPIO, UART, and
timers, hard and soft callbacks, and the `machine` / `time` surface those
need.

Revision 1 (the I/O and USB coprocessor work) changes §3 and §10. It
adds UART FIFOs and clock dividers, GPIO direction and pulls, per-pin
handlers in firmware, Ctrl-C, console routing, the REPL, and new MMIO
blocks. USB runs on an RV32EMC coprocessor behind a mailbox; that
subsystem has its own spec, [`upycore/docs/mpy_coproc.md`](../upycore/docs/mpy_coproc.md).
This file only owns the hart side of it: the `MBOX` and `KBD` sources,
the mailbox registers in the window, and the natives.

Product decisions stay in [`micropython_pivot_plan.md`](micropython_pivot_plan.md)
§5 and in [`mpy_review/merged_plan.md`](mpy_review/merged_plan.md) phase 5.
The register rules stay in [`upycore/docs/mpy_peripherals.md`](../upycore/docs/mpy_peripherals.md).
Do not copy that table into this file. Where this file names a pin
function, the pin is MicroPython v1.29.0.

## 1. What is already true

- `upycore/rtl/mpy_periph.sv` and `upycore/rtl/mpy_irq.sv` implement the
  v1 window at `0x4000_0000`: UART, GPIO, the timer, the IRQ register
  file, and the depth-8 schedule ring. `upycore/tb/tb_mpy_periph.sv`
  checks blink, echo, overrun, and the ninth `schedule` against
  `upycore/tools/mpy_periph_model.py`. That bench drives the block on
  its own bus. It is not part of `make test`.
- Delivery, as that block already implements it: a hard source is taken
  at a one-cycle `bc_boundary` pulse; a soft source is queued on a
  one-cycle `jump` pulse; `micropython.schedule` pushes the same ring;
  `fire` stays high until `done`; `heap_locked` is high only while a
  hard callback is running. Global enable does not gate `schedule`.
- The hart already has the pieces a callback needs, unused. Frame spill
  and `S_CALL` call a function, a bound method, or a native. `S_AL`
  raises through the emergency object at `ABI_SR_EMERG`. The message
  table already has `ABI_MSG_HEAP_LOCKED`, `ABI_MSG_SCHED_FULL`, and
  `ABI_MSG_KBD`. `_irq_uncaught` is a firmware hook and reads
  `SR_IRQ_EXC`. It currently prints and halts.
- `gc_root1` is the half-open span `[ABI_SCHED_BASE, ABI_GC_POOL_BASE)`.
  That span already covers the schedule ring, the handler table, the
  sysroot, and the argument buffer. As built, those bases are
  `0x2000_8000`, `0x2000_8040`, `0x2000_8080`, and `0x2000_8500`
  (`upycore/rtl/mpy_abi.svh`). [`upycore/docs/mpy_memory_map.md`](../upycore/docs/mpy_memory_map.md)
  still draws the older 16 KB frame split. The header in `mpy_abi.py`
  is the map.

## 2. The gap

`mpy_soc` does not instantiate `mpy_periph`. `mpy_mem` treats the MMIO
window as a bus fault, so `_peek32` of `GPIO_OUT` never reaches the
block. Nothing pulses `bc_boundary`, `jump`, or `done`. `fire` is not
a call. Handler and ring entries are 32-bit payloads with no tag, so
the collector cannot tell a function from an integer that happens to
look like a pointer.

`_mp_sched` calls the function immediately. `_mp_lock` and `_mp_kbd`
return. `print` writes the sim console (`ABI_N_WR` / `ABI_N_WE` to
`0xE000_0000`), which is what the hardware suite compares. There is no
`machine` module and no `time` module.

The IRQ block latches `pc`, `fp`, `sp`, and `exc_sp` on a hard entry.
That is not this hart's frame. A return has to restore the frame record
`S_FILL` already knows: previous frame, raw code, PC, stack depth,
exception stack, flags, return kind, globals, the register file, and
the local cache. A second restore path from those four words would drop
the rest.

## 3. Decisions

These are the incorporation choices. Changing one is a revision of this
file. The register rules are not among them.

| Topic | Choice |
| --- | --- |
| Bus | `mpy_soc` steers `MPY_REGION_MMIO` to `mpy_periph`. SRAM and flash stay in `mpy_mem`. The sim page stays in `mpy_soc` |
| `print` | The sim console by default, so `make test` stdout does not change. A boot strap (`console_sel_i`, the testbench's `+CONSOLE=` plusarg) or `os.dupterm` moves `sys.stdout` and `sys.stdin` to the UART or to USB CDC. The strap is read once by `_boot`. `machine.UART` is the MMIO UART either way |
| Callback | An ordinary `S_CALL` of `fire_fn(fire_arg)`, return kind `ABI_RK_IRQ`. The frame spill is the interrupted state. `saved_pc` / `saved_fp` / `saved_sp` / `saved_exc_sp` stay debug taps |
| Tags | Payload ports stay 32 bits so `tb_mpy_periph` keeps comparing payloads. New tag sidebands travel with every handler word, ring slot, and `schedule` push. An empty handler is payload 0 |
| Roots | The flop file remains the delivery copy, because one jump may enqueue every soft source in the same cycle. Before the next opcode, and before a collection, the core mirrors occupied slots into the SRAM windows `gc_root1` already scans |
| Handler base | Fixed at `ABI_HANDLER_BASE`. `IRQ_TABLE` still round-trips for the unit bench. The hart does not relocate the root |
| Soft point | The same opcodes as `py/vm.c` `pending_exception_check`: `JUMP`, `POP_JUMP_IF_TRUE`, `POP_JUMP_IF_FALSE`, `JUMP_IF_TRUE_OR_POP`, `JUMP_IF_FALSE_OR_POP`, `UNWIND_JUMP`, `POP_EXCEPT_JUMP`. Taken or not. `FOR_ITER` is not one of them |
| Hard point | The next opcode boundary, which on this core is `S_FETCH` after the previous opcode has committed and after a spill or reload |
| Nesting | None. `fire` already holds off the next callback. A second priority level stays out |
| Heap lock | `S_AL` does not collect while the lock is set. It raises `ABI_MSG_HEAP_LOCKED` through the emergency object. The lock is the OR of the hard-IRQ lock and a software nesting counter |
| Uncaught hard IRQ | Banner on stderr while `fire` is still high, then disable that source, then `done`, then the traceback. The source disable matches `mp_irq_handler` in v1.29.0 `shared/runtime/mpirq.c`: clear the handler word and that source's enable bit |
| Uncaught soft callback | Traceback on stdout, no banner, source left armed. That is `mp_call_function_1_protected` in `py/runtime_utils.c`, which prints to `mp_plat_print` |
| Tick | `timer_step` is the millisecond. It is the OR of the `timer_step_i` pin and a prescaler, `TIMER_PRESC`, that counts system clocks. Prescaler 0 is off, so the testbench's `+TIMER_STEP` pin stays the override and existing traces do not move. Compare values and `time.ticks_ms` count ticks, not core cycles. Compare 0 still disables the timer, so ticks during boot do nothing |
| UART FIFOs | RX and TX FIFOs of `UART_FIFO_DEPTH` entries, default 16. Bit 30 of `UART_RX` still sticks, and now means a byte arrived while the RX FIFO was full. The 17th unread byte is the one that overruns. The unit bench instance is depth 1, so its echo trace is bit-identical |
| Baud | `UART_BAUD` holds system clocks per bit. 0, the reset value, is byte mode: the testbench strobes whole bytes in, and a TX store leaves on `uart_tx_stb` in that cycle, as before. N > 0 runs an 8N1 serializer on `uart_txd_o` and a deserializer on `uart_rxd_i`. `machine.UART(0, baudrate=b)` writes `freq // b` |
| GPIO direction | `GPIO_OE`, `GPIO_PULLUP`, and `GPIO_PULLDOWN` are outputs to the pad wrapper. Pulls are not modeled in RTL. `Pin.OUT` sets the OE bit, `Pin.IN` clears it. `Pin(id, mode, pull)` follows v1.29.0 |
| Per-pin handlers | The hardware GPIO slot stays one slot. `GPIO_STATUS` latches the pins whose edge matched, write 1 to clear. The slot's callback is the firmware dispatcher; it clears the bits it saw and calls each pin's handler with the `Pin`, lowest pin first. A second `Pin.irq` on another pin adds a handler. The slot is hard when any armed pin is hard. A hard dispatch calls hard pins directly and passes soft pins to `micropython.schedule`, which does not allocate. A soft dispatch calls every pin directly |
| Sources | Eight: the six of v1, then `KBD` (6) and `MBOX` (7). Eight is what the 64-byte handler window at `ABI_HANDLER_BASE` holds, so the memory map does not move. SPI, I2C, PWM, WDT, and ADC set status bits in their own blocks and are polled from Python. A source for one of them needs a 128-byte window, which moves `ABI_SYSROOT_BASE` and the GC pool; that is a separate decision |
| Ctrl-C | `KBD` has no handler. When it is pending and enabled, the next soft point raises `KeyboardInterrupt` (`ABI_MSG_KBD`) in the running frame instead of taking a callback. A hard callback holds it off; a soft callback can be interrupted. Sources: the coprocessor's `KBD` doorbell, and a UART RX byte equal to `UART_KBD`'s character while the UART is the console. That byte is not queued. `micropython.kbd_intr(c)` writes the character; `-1` disarms both sources |
| New blocks | Each block is an offset range in the window, after the ticks register, under the same delivery rule. `MBOX` `0x100`, `PWM` `0x200`, `SPI` `0x300`, `I2C` `0x400`, `WDT` `0x500`, `SYS` `0x600`, `TIMER1..3` `0x700`, `ADC` `0x800`, `PINMUX` `0x900`. Registers are recorded in `mpy_peripherals.md` before the RTL that uses them |
| REPL | A friendly REPL and a raw REPL (`Ctrl-A`, `Ctrl-B`, `Ctrl-C`, `Ctrl-D`, paste mode `Ctrl-E`) in firmware, on the console the strap selects. It runs after `__main__` returns, when the strap asks for it. Compilation is the on-device uPy2 compiler that the `compiler` area already tests |
| `GC_REQ`, idle GC | Not this plan. The source bit stays reserved |

## 4. The bus

`mpy_soc` gains the peripheral ports the block already has: `timer_step_i`,
`uart_rx_stb_i`, `uart_rx_byte_i`, `uart_tx_stb_o`, `uart_tx_byte_o`,
`gpio_out_o`, plus `gpio_in_i` and `gpio_in_en_i`. Revision 1 adds
`gpio_oe_o`, `gpio_pu_o`, `gpio_pd_o`, `uart_txd_o`, `uart_rxd_i`,
`console_sel_i`, and the ports of each new block.

`gpio_in_en_i` is how the two GPIO-in writers coexist. The unit bench
leaves it low and still presents a pin by storing `GPIO_IN`. The SoC
bench ties it high and drives `gpio_in_i`. A store and a pin sample in
the same cycle: the store wins. Either writer runs the existing edge
function. `tb_mpy_periph` must not change its traces.

A core load or store whose region is MMIO is presented to `mpy_periph`
and does not enter `mpy_mem`. Ack, read data, and fault come back on
the core's memory port. Unaligned and out-of-window faults stay faults.
Unimplemented offsets inside the window still read as 0 and ignore
writes.

`_peek32` is already a raw word load. Add `_poke32(addr, word)`,
appended to `NATIVES` in `upycore/tools/mpy_abi.py` so existing native
ids do not move. The store writes the raw word and tag `CONTROL`, so a
`mem32` poke is not a GC root. `_ld` / `_st` stay object-relative.

`tb_mpy_soc` grows the pins and two plusargs. `+TIMER_STEP=N` pulses
`timer_step` every N cycles for the whole run (boot is safe because
compare resets to 0). `+UART_RX=` is a byte string pushed one byte at
a time while the core is in `machine.idle`. `+MAX_TICKS=N` stops the
run after N pulses and compares the GPIO edge mask and the UART TX
bytes with `mpy_periph_model.py`. That stop is a trace pass, not halt
code 0. Programs that return still use the halt line.

## 5. Delivery

### Poll

`S_FETCH` is the boundary, with one exception: a spill or reload
resumes at `S_FETCH` and is not a new opcode. Order inside `S_FETCH`:

1. Spill or reload if the register ring needs it. `need_poll` stays set.
2. If `need_poll`, go to the poll sequence and clear it.
3. Otherwise fetch or decode, as today.

`S_DEC` sets `need_poll` when it hands an opcode to `S_EXEC`. Reset
starts with `need_poll` set, so the first instruction is a boundary.
A GC abort that re-dispatches the same opcode does not go through
`S_FETCH`, so it does not poll. The collection stays inside that
opcode's latency.

The jump opcodes set `irq_jump` on the path that actually retires them,
including `S_JT`, `S_UJ`, and the `S_XPOP` that finishes
`POP_EXCEPT_JUMP`. The poll consumes the flag. A spill before the poll
must not drop it.

Audit every `st <= S_FETCH` that continues an opcode rather than ending
one. Those paths have to clear `need_poll` for that entry. `gosub` /
`ret` are not fetch and are not boundaries.

The poll sequence is three states, and `bc_boundary` / `jump` are high
only in the first:

1. **Poll.** Pulse `bc_boundary`. Pulse `jump` too when `irq_jump` is
   set. `fire` updates on the clock edge at the end of this state.
2. **Mirror.** If the flop file is dirty, write it into SRAM (§7).
   The push that just landed is in the flop file before this step.
3. **Take.** If `fire` is high, build the call. Otherwise decode.

`done` is its own later cycle, with both pulses low. The block already
ignores a new start on the cycle `done` clears `fire`.

Two cycles plus a dirty mirror sit between opcodes. A dirty mirror is
at most 32 tagged words (8 ring slots and 8 handler slots, two words
each). SRAM latency is 1. That is the v1 hard-IRQ latency on top of
whatever opcode was in flight, including a collection the opcode
already started. GC is not preempted.

### The call

Reuse `S_CALL`. Slot 0 of the argument buffer is the callable. The
argument is the word at `ABI_ARGBUF_ARGS` (32). `ab_lo` is 32, `ab_pe`
is 33, `ab_nkw` is 0, `crk` is `ABI_RK_IRQ`. Tags come from the new
sidebands. `S_CALL` already dispatches a function, a bound method, a
native, and a type.

`ABI_RK_IRQ` is the next return kind (the file has five). `S_DELIVER`'s
default arm halts with the clean-halt code. The new kind needs its own
arm: pulse `done` for one cycle, then `S_FETCH` of the restored frame,
or `S_IDLE` when the callback was taken from idle. Do not leave it in
the default.

`S_RAISE` stops when the frame it would unwind has `frk == ABI_RK_IRQ`.
It does not fill the caller and raise again. Hard and soft diverge in
§6. A callback that needs another frame uses the same 32 KB reserve and
the same recursion `RuntimeError`.

### Idle

`machine.idle` is a native, appended like `_poke32`. It parks in
`S_IDLE` without retiring an opcode per clock, so a `while True` around
it does not burn `+MAX_CYCLES` between ticks.

Each `timer_step`, UART strobe, or enabled GPIO edge wakes it. On entry,
and on each wake, it runs the same poll sequence with `jump` held low.
A hard callback taken there returns to `S_IDLE` (`idle_resume`), which
polls once more before sleeping. When that poll sees `fire` low, idle
returns `None`. The `while` loop's `JUMP` is then the soft-callback
point. Compare 0 produces no wake from the timer. The testbench's
free-running `timer_step` is what makes the loop progress.

## 6. Heap lock, schedule, and uncaught handlers

The software counter lives in a core register, not in a sysroot word,
so `S_AL` can read it without a load. `micropython.heap_lock` increments
it and returns `None`. `micropython.heap_unlock` decrements it, floors
at 0, and returns the new depth. That is `py/modmicropython.c` at
v1.29.0. Today's stubs return `None` for both. The hard-IRQ lock ORs
with the counter and is not part of the depth `heap_unlock` returns.

While the OR is set, `S_AL` skips the collect-and-retry and raises
`ABI_MSG_HEAP_LOCKED` (`MemoryError: memory allocation failed, heap is locked`).
The emergency object is the exception. No firmware frame.

`micropython.schedule(fn, arg)` becomes a native pulse of `sched_push`
with both tags. The native waits one cycle, the same handshake as
`do_sched` in the unit bench. `sched_ok` returns `None`. `sched_full`
raises `ABI_MSG_SCHED_FULL`. The ninth push is the one that raises.
`_mp_sched` stops calling the function itself.

Global enable is a native too. `machine.disable_irq` reads `IRQ_GIE`
and clears it in one opcode, with no `S_FETCH` between the read and the
write, and returns the old bit. `machine.enable_irq(state)` writes bit
0. A firmware peek-then-poke is not this, because a jump in between is
a soft point.

Uncaught callback, in order:

1. The exception is stored at `SR_IRQ_EXC`.
2. **Hard.** While `fire` is still high, write
   `Uncaught exception in IRQ callback handler\n` to stderr through the
   sim console. No allocation. Clear that source's handler payload and
   its `IRQ_ENABLE` bit. Leave `GPIO_EDGE` as the program set it.
   Pulse `done`.
3. **Soft, or a `schedule` callback.** Leave the source armed. Pulse
   `done` before printing. The traceback goes to stdout.
4. Call the existing `_irq_uncaught` hook. It prints the traceback and
   returns. It must not halt. `_boot` remains the halt path for
   `__main__`.
5. `S_FETCH` of the interrupted frame.

The pin prints a hard traceback on stderr before `gc_unlock`. Our
`_print_tb` allocates, so the traceback body runs after `done`. The
banner does not. A hard handler that only raises `MemoryError` is the
exit test, and the golden stderr is the banner, then the traceback
`_print_tb` already emits, including
`MemoryError: memory allocation failed, heap is locked`.

`_irq_uncaught` runs with `fire` low, so another source may preempt it.
The source that just failed cannot, because its enable bit is clear.

## 7. GC

Extend `mpy_sched_entry_t` and the handler flops with a tag for the
function and a tag for the argument. `handler_we` and `sched_push` gain
matching tag inputs. Tie them to 0 in `tb_mpy_periph`. Payload
comparisons in that bench stay valid.

The core mirrors when a handler write, a push, or a pop has happened
since the last mirror:

| SRAM | Contents |
| --- | --- |
| `ABI_SCHED_BASE + 8*(i mod 8)` | Ring slot `i`, function then argument, tagged. A slot outside `[head, tail)` is the empty word |
| `ABI_HANDLER_BASE + 8*src` | Handler function and argument for that source |

The mirror uses the core's tagged store. It finishes in the poll's
mirror step, and `S_GC` waits for a clean mirror before it requests a
collection. After that, no GC port change is required: `gc_root1`
already walks those addresses, and the hi address is exclusive.

A function that is queued and then dropped by the program must survive
the next collection. That is the root test. An integer argument whose
payload is a heap address must not keep that address alive.

`IRQ_TABLE` is not consulted. Relocating it would move the objects out
of `gc_root1`.

## 8. Python surface

`machine` and `time` are firmware modules built the way `sys`, `gc`, and
`micropython` are built, from `_boot`, and stored in the two unnamed
sysroot slots at indexes 28 and 29. Those words are already inside the
rooted sysroot. Do not grow `ABI_SYSROOT_WORDS`. `_load_mod` returns
them by name, so `import machine` and `from machine import Pin` use the
import path that already exists.

The unix port's `machine` is not the oracle. Trace programs do not go
through `make test`'s stdout compare. `schedule`, `heap_lock`, and
`ticks_diff` do, because the pin implements those.

`Pin.irq`, `Timer.init`, and `UART.irq` wrap their register writes in
`disable_irq` / `enable_irq`. The handler write is the `_irq_handler`
native (`handler_we`). Enable, hard, edge, and compare are `_poke32`.

| Operation | Effect |
| --- | --- |
| `Pin(id, mode, pull)` | `id` is 0..15. The object remembers the id. `Pin.OUT` sets the `GPIO_OE` bit and `Pin.IN` clears it. `Pin.PULL_UP` and `Pin.PULL_DOWN` set the pull bits |
| `Pin.value()` / `Pin.value(v)` | Read the input bit, or read-modify-write the output bit |
| `Pin.irq(handler, trigger, hard=False)` | `GPIO_EDGE` for that pin (`00` off, `01` rising, `10` falling, `11` both), the pin's entry in the firmware table, handler slot `GPIO` (the dispatcher), `IRQ_HARD`, `IRQ_ENABLE`. One slot serves every pin; each pin keeps its own handler |
| `Timer(0).init(period, callback, hard=False)` | `period` is a compare in `timer_step` pulses. Store `TIMER_COUNT`, handler slot `TIMER`, enable, hard |
| `UART(0, baudrate=)` / `write` / `read` / `any` | `baudrate` writes `UART_BAUD`. Store each byte to `UART_TX`, waiting while the TX FIFO is full. A load of `UART_RX` pops and reports bit 31 and bit 30. `any` reads the RX level in `UART_STATUS`. `UART.irq` arms the UART source |
| `mem32[addr]` | `_peek32` / `_poke32` |
| `disable_irq` / `enable_irq` | The atomic native in §6 |
| `idle` | §5 |
| `time.ticks_ms` | A free-running count of `timer_step`, new read-only register at the next free offset past `0x34`. Record it in `mpy_peripherals.md` before the RTL |
| `time.ticks_diff` / `ticks_add` | Firmware, wrapping 32-bit subtract and add. Oracle-compared |
| `time.sleep_ms(n)` | `n` times: `idle` until `ticks_ms` has moved. Not a cycle spin |

`Timer(id)` for an id the SoC does not have and `UART(id)` for `id != 0`
raise `ValueError`. One UART, sixteen pin bits. The extra timers are
§3's `TIMER1..3` block.

## 9. Slices

Each slice keeps `tb_mpy_periph` passing and keeps `make test` passing.
Native ids are only appended.

### A. Bus

Steer MMIO. Add `_poke32`. Expose the pins on `mpy_soc` and `tb_mpy_soc`.

Exit: a one-opcode store to `GPIO_OUT` changes `gpio_out_o`. A load of
`UART_RX` pops. An address outside the window still bus-faults.
`tb_mpy_periph` traces are unchanged. The existing image suite does not
touch the window, and its stdout is unchanged.

### B. Tags and the mirror

Tag sidebands, tied off in the unit bench. Mirror into the two SRAM
windows. `S_GC` waits until the mirror is clean.

Exit: a handler whose only Python reference was dropped is still called
after `gc.collect()`. An int argument does not retain a decoy object.
`upycore/docs/mpy_memory_map.md` is corrected to the bases in §1 in this
slice.

### C. The hart path

Poll, `ABI_RK_IRQ`, `done`, the heap-lock check in `S_AL`, the schedule
native, the GIE native, and `_irq_uncaught` returning instead of halting.

Exit: `micropython.schedule` of eight callbacks runs one per `JUMP`, and
the ninth raises `RuntimeError: schedule queue full` with the oracle's
stdout and stderr. `heap_lock()` prints `None`, and `heap_unlock()`
prints `0` after a single lock. A hard handler that allocates prints the
banner and the `MemoryError` line on stderr and the program after the
handler still runs. A raising `schedule` callback prints its traceback
on stdout and does not halt.

### D. `machine`, `time`, idle

The modules, the pins on the SoC bench, and `+MAX_TICKS`.

Exit: blink, compare 4, soft timer, 20 ticks. `GPIO_OUT` bit 0 toggles
at ticks 4, 8, 12, 16, and 20. The same mask with extra idle clocks
between ticks. Compare 0 over 20 ticks produces no edges. Echo, with the
16-entry FIFO: `0x41` and `0x42` come back on TX; `0x43` and `0x44` are
buffered while the callback is held off and come back in order; bit 30
stays clear. A run that holds off the reader for 17 bytes sets bit 30
once, and the first 16 come back. Two pins with different handlers both
fire, in edge order. 64 bytes at the modeled baud rate during a forced
`gc.collect()` arrive intact; with the FIFO depth below the collection's
length in byte times, overrun sets exactly when the model says it does.
`Pin.OUT` drives `gpio_oe_o`; `Pin.IN` releases it. `sleep_ms` and `ticks_diff` match the oracle
for a value test that does not depend on the pin. Debounce is a pin
IRQ plus `ticks_diff` against the host model.

`upycore/docs/mpy_interrupts.md` is written in this slice, from this
file, once the behavior is true. It does not replace
`mpy_peripherals.md`.

## 10. Out of this plan

- `GC_REQ`, collecting from `idle`, and a hard IRQ in the middle of a
  mark. Latency includes one full collection.
- A second IRQ priority, nesting, and preempting `fire`.
- Per-pin handler *slots* in hardware. Per-pin handlers are firmware
  (§3).
- IRQ sources for SPI, I2C, PWM, WDT, and ADC (§3, Sources).
- The USB stack itself, `machine.USBDevice`, DFU, and the filesystem.
  They live on the coprocessor ([`upycore/docs/mpy_coproc.md`](../upycore/docs/mpy_coproc.md)).

Revision 1 moved these into the plan: Ctrl-C and `KeyboardInterrupt`;
SPI, I2C, ADC, PWM, and WDT; the baud generator and the UART FIFOs;
retargeting `print`; the REPL.
