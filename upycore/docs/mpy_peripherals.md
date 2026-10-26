# MicroPython peripherals

Status: the v1 register model, with the revision 1 additions of
[`planning/interrupts_io_plan.md`](../../planning/interrupts_io_plan.md)
§3. The RTL is `upycore/rtl/mpy_periph.sv` and `upycore/rtl/mpy_irq.sv`.
The executable copy of the edge, UART, and tick rules is
`upycore/tools/mpy_periph_model.py`.

This file is the host register model. Blink and echo traces are checked
against it. The unix port's `machine` module is a different peripheral
model and is not the oracle for edges. `print` and
`micropython.schedule` overflow text still come from the unix oracle
(`RuntimeError: schedule queue full`).

`machine` and the IRQ half of `micropython` are native modules. They are
not frozen `.mpy` files. The hart's builtin table is what will call into
this block. Nothing in this change freezes a `machine` image.

This block does not implement the REPL. It raises the `KBD` source for a
UART byte that matches `UART_KBD`; the hart turns that source into
`KeyboardInterrupt`.

## Window

| Window | Base | Size |
| --- | --- | --- |
| MMIO | `0x4000_0000` | 4 KB |

The slave accepts a full address in that window, or an offset whose upper
bits are already 0. A store or load whose address is outside the window,
or whose address is not 4-byte aligned, raises `fault` and changes no
register. The memory fabric still owns the bus-fault halt for a store to
flash and for an access outside flash, SRAM, and the two MMIO windows.
Little-endian. Unimplemented offsets inside the window read as 0 and
ignore writes.

## Registers

The six draft offsets stay put. Added registers start at `0x18`.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `UART_TX` | A store of bits 7:0 sends that byte. With `UART_BAUD` 0 the byte leaves on `uart_tx_stb` in the same cycle, as in v1. Otherwise it joins the TX FIFO; a store while the FIFO is full is dropped. A load returns the last byte stored |
| `0x04` | `UART_RX` | The head of the RX FIFO. A load returns the byte in bits 7:0 and pops it. Bit 31 is data-valid. Bit 30 is overrun: a byte that arrives while the FIFO is full is dropped, and bit 30 sticks. Bit 29 is a framing error from the serial receiver; that byte is dropped and bit 29 sticks. Writing 1 to bit 30 or bit 29 clears it. The pop leaves both alone. With depth 1 this is the v1 single-byte buffer |
| `0x08` | `GPIO_OUT` | Read/write. A blink toggles with a read-modify-write |
| `0x0C` | `TIMER_COUNT` | A load returns the counter. A store sets the compare period and does not change the counter. Zero disables the timer. On match the counter returns to 0 and the timer IRQ bit sets |
| `0x10` | `IRQ_STATUS` | Pending sources. Write 1 to clear. Accepting a callback for a source also clears that source. An edge during the callback sets the bit again |
| `0x14` | `IRQ_ENABLE` | Mask. See the source table |
| `0x18` | `IRQ_HARD` | Per source. 1 delivers hard, 0 delivers soft |
| `0x1C` | `IRQ_GIE` | Bit 0 is the global enable. `machine.disable_irq` returns the old value; `enable_irq(state)` writes it back |
| `0x20` | `IRQ_ACTIVE` | Read-only. Bit 0 is set while a hard handler is running |
| `0x24` | `IRQ_TABLE` | Base of the handler table. One function word and one argument word per source: function at `base + 8*src`, argument at `base + 8*src + 4`. The words are GC roots |
| `0x28` | `SCHED_HEAD` | Free-running pop index. The ring slot is the index mod 8 |
| `0x2C` | `SCHED_TAIL` | Free-running push index. Occupancy is `(tail - head) mod 256`, and it never exceeds 8. Equal head and tail means empty; a difference of 8 means full |
| `0x30` | `GPIO_IN` | Input word. A store is how the testbench presents a pin level. Pin IRQ uses the change |
| `0x34` | `GPIO_EDGE` | Two bits per pin, pin 0 in bits 1:0, for pins 0 through 15. `00` off, `01` rising, `10` falling, `11` both |
| `0x38` | `TICKS` | Read-only. Free-running count of ticks (see Timer tick). Wraps at 2^32. `time.ticks_ms` reads it |
| `0x3C` | `UART_BAUD` | System clocks per bit. 0 is byte mode: the testbench strobes whole bytes in, and TX bypasses the FIFO. N > 0 runs the 8N1 serializer on `uart_txd` and the receiver on `uart_rxd` at N clocks per bit. N below 4 is treated as 4 |
| `0x40` | `UART_STATUS` | Read-only. Bits 7:0 RX level, bits 15:8 TX level, bit 16 TX busy (FIFO not empty or a frame on the wire), bit 17 RX full, bit 18 TX full |
| `0x44` | `TIMER_PRESC` | System clocks per tick. 0 turns the prescaler off. The tick is the OR of `timer_step` and the prescaler's pulse |
| `0x48` | `GPIO_OE` | Output enable per pin, to the pad wrapper. Reset 0, every pin an input |
| `0x4C` | `GPIO_PULLUP` | Pull-up enable per pin, to the pad wrapper. Not modeled in RTL |
| `0x50` | `GPIO_PULLDOWN` | Pull-down enable per pin, to the pad wrapper. Not modeled in RTL |
| `0x54` | `GPIO_STATUS` | One bit per pin, set when that pin's `GPIO_EDGE` mode matches a change. Write 1 to clear. Independent of `IRQ_STATUS`: the `GPIO` source bit sets on the same edge |
| `0x58` | `UART_KBD` | Bits 7:0 the interrupt character, bit 8 enable. A received byte that matches while enabled sets the `KBD` source and is not queued. Reset 0, disabled |

Source bits in `IRQ_STATUS`, `IRQ_ENABLE`, and `IRQ_HARD`:

| Bit | Source |
| --- | --- |
| 0 | `TIMER0` compare match |
| 1 | `UART_RX` byte accepted into the empty buffer |
| 2 | `GPIO` pin edge |
| 3 | `SOFT` |
| 4 | `GC_REQ` |
| 5 | `SIM` testbench stimulus |
| 6 | `KBD` keyboard interrupt (UART character or coprocessor doorbell) |
| 7 | `MBOX` coprocessor doorbell |

`SOFT`, `GC_REQ`, `SIM`, `KBD`, and `MBOX` set their status bit from a
one-cycle pulse (`soft_set`, `gc_req`, `sim_set`, `kbd_set`, `mbox_set`);
`KBD` also sets from `UART_KBD`. A byte accepted into the RX FIFO sets
the UART bit. A dropped UART byte does not set it again, and the bytes
already queued are still the bytes a load returns.

`KBD` is not a callback. The hart raises `KeyboardInterrupt` for it at
a jump opcode; see Delivery.

Reset: `IRQ_GIE` is 1. Enable, hard, and status are 0. Compare, counter,
ticks, prescaler, baud, GPIO (including OE, pulls, and status), UART, the
FIFOs, and the schedule indexes are 0. Handler slots are empty (function
word 0). An empty function word is not a callback: the source stays
pending until a handler is written.

The block is parameterized by `UART_FIFO_DEPTH` (default 16). The unit
bench instantiates depth 1, which is the v1 buffer.

## Timer tick

The phase 5 timer advances on a tick: a rising clock with `timer_step`
high, or with the prescaler's pulse. The prescaler counts system clocks
and pulses once every `TIMER_PRESC` clocks; 0 turns it off. A store to
`TIMER_PRESC` restarts its count. `TICKS` counts every tick, whatever
the compare. A cycle-stepped mode is a later plusarg, so a blink
trace does not move when an opcode takes more clocks. The testbench
pulses `timer_step` once per tick and may insert idle clocks around it.

Compare 0 disables the timer: `timer_step` does not change the counter
and does not set the timer status bit. Compare `N > 0` matches when the
next count would be at least `N`. The counter becomes 0 and the timer
status bit sets. After reset the counter is 0, so the first match is on
tick `N`, then every `N` ticks.

## UART

The RX FIFO and the TX FIFO each hold `UART_FIFO_DEPTH` bytes. Bytes
enter the RX FIFO from the `uart_rx_stb` byte strobe (both modes) or
from the serial receiver (`UART_BAUD` > 0). The receiver synchronizes
`uart_rxd`, finds the falling edge of the start bit, samples it again
half a bit later, then samples eight data bits LSB first and the stop
bit at one-bit intervals. A start bit that is high again is a glitch. A
stop bit that is low is a framing error.

The serializer takes the oldest TX FIFO byte when the line is idle,
pulses `uart_tx_stb` with that byte, and drives the start bit, eight
data bits LSB first, and one stop bit on `uart_txd`, which idles high.
In byte mode `uart_txd` stays high.

A pop and an arrival in the same cycle: the arrival is judged against
the level before the pop, so a full FIFO drops it. That is the v1 rule
for depth 1.

## GPIO

`gpio_in` is sampled through a two-flop synchronizer while `gpio_in_en`
is high. A store to `GPIO_IN` and a sample in the same cycle: the store
wins. Either writer runs the edge check against the previous `GPIO_IN`.
`GPIO_OE`, `GPIO_PULLUP`, and `GPIO_PULLDOWN` are plain registers whose
bits leave on `gpio_oe`, `gpio_pu`, and `gpio_pd`.

## Handler table

`mpy_irq` holds eight slots, one per source. The `KBD` slot is not
read: that source raises instead of calling. The native `machine` module writes a slot
when `Pin.irq`, `Timer`, or `UART.irq` runs. The port is `handler_we`
with the source index, the function word, the argument word, and a tag
for each word; the `_irq_handler` native drives it. A `micropython.schedule`
push carries the same two tags, and every ring slot keeps them.

The flops are the delivery copy. They are GC roots through a mirror:
`mirror_dirty` rises on a handler write, a push, or a pop, and the hart
reads every slot through `mirror_sel` (0–7 ring slots, 8–15 handler
slots; `mirror_fn`/`mirror_arg` are tag and payload) into the SRAM
windows `upycore/docs/mpy_memory_map.md` gives, then pulses
`mirror_clr`. A ring slot outside `[head, tail)` reads as the empty
word. A change on the clock of the clear keeps the flag set.

## Delivery

`bc_boundary` is a one-cycle pulse at a bytecode boundary. `jump` is a
one-cycle pulse on `JUMP`, `POP_JUMP_IF_*`, `JUMP_IF_*_OR_POP`,
`UNWIND_JUMP`, and `POP_EXCEPT_JUMP`. A jump is also a boundary, so the
core pulses both. `done` is a one-cycle pulse when that callback's
`RETURN_VALUE` retires.

Armed bits are `(IRQ_STATUS | event this cycle) & IRQ_ENABLE`. Global
enable gates device delivery. It does not gate `micropython.schedule`.

On a clock where no callback is running:

1. If `bc_boundary` and a hard source is armed and its function word is
   not 0, take the lowest such source. This includes a jump, because a
   jump is a boundary. Hard wins over soft on that clock.
2. Otherwise, if `jump` and global enable is on, append each armed soft
   source whose function word is not 0, lowest index first, while the
   ring has fewer than 8 entries. Accepting a source into the ring
   clears its `IRQ_STATUS` bit.
3. If `sched_push` and the ring has fewer than 8 entries after step 2,
   append `(fn, arg)` from `micropython.schedule`. If the ring already
   holds 8, `sched_full` pulses and the native builtin raises
   `RuntimeError: schedule queue full`. The ninth push is the one that
   raises when none have been popped.
4. If this clock did not start a hard callback, and `jump` is set, and
   the ring is not empty, pop one entry and start it. A callback that
   was queued in step 2 on an empty ring runs on that same jump.

`KBD` is checked on a jump when no hard callback is running and global
enable is on, so a soft or `schedule` callback can be interrupted. If
step 1 did not start a hard callback and `KBD` is armed, `kbd_raise`
pulses for that clock, the `KBD` status bit clears, and steps 2 and 4
do not run on that clock. The hart raises `KeyboardInterrupt` in the
running frame. Queued callbacks stay queued for the next jump.

`fire` stays high until `done`. A second callback does not start while
it is high. `heap_locked` and `sched_locked` are high only for a hard
callback. A soft callback and a `micropython.schedule` callback leave
the heap unlocked, so that callback may allocate. `IRQ_ACTIVE` follows
the hard callback only.

Accepting a callback clears that source's status bit on the clock the
callback is taken (hard) or queued (soft). The event that caused the
accept does not stick. A later event while the callback is running sets
the bit again. Write-1-to-clear still works. A source that cannot be
queued because the ring is full keeps its status bit.

A hard entry latches `pc`, `fp`, `sp`, and the exception-stack pointer.
`done` drops `fire`, `heap_locked`, `sched_locked`, and `IRQ_ACTIVE`.
Restoring the frame is the hart's return path. There is no nesting.

`sched_locked` stops a new callback from starting. It still allows
`micropython.schedule` to push. A push is refused only when the ring
already holds 8 entries.

## Native `machine`

The module is native. The operations this block backs:

| Operation | Effect |
| --- | --- |
| `Pin` / `GPIO_OUT` / `GPIO_IN` | Read-modify-write of `GPIO_OUT`. `GPIO_IN` is the pin level. `GPIO_EDGE` is the trigger |
| `Pin.irq(handler, trigger, hard)` | Writes that source's handler slot and `IRQ_HARD` |
| `Timer` compare and callback | Stores `TIMER_COUNT`, writes the timer slot, sets enable and hard |
| `UART` read, write, `irq` | Load `UART_RX`, store `UART_TX`, write the UART slot |
| `mem32` | Word load/store in this window |
| `disable_irq` / `enable_irq` | Read and write `IRQ_GIE` |
| `idle` | The hart waits. A timer that is already armed keeps its compare |

`micropython.schedule(fn, arg)` pulses `sched_push`. The ring depth is 8,
the same value `MICROPY_SCHEDULER_DEPTH` has on ESP32, RP2, and STM32.

## Exit trace

`python3 upycore/tests/test_mpy_periph_model.py` runs the model.
`make test-benches` (`upycore/tools/run_benches.py`) verilates and runs
the RTL benches with the model's plusargs: `upycore/tb/tb_mpy_periph.sv`
(the v1 traces, FIFO depth 1) and `upycore/tb/tb_mpy_periph_io.sv` (the
revision 1 registers, depth 16). `make test` runs them too. The `io`
area of `upycore/programs/hw_tests.toml` runs programs on the SoC.

Blink: compare 4, soft timer IRQ, 20 ticks. The callback toggles
`GPIO_OUT` bit 0 at the jump on ticks 4, 8, 12, 16, and 20 (five edges).
The same edge mask is required when the testbench inserts extra idle
clocks between ticks. Compare 0 over the same 20 ticks produces no edges.
A disabled timer also leaves a partially advanced counter where it was.

Echo: bytes `0x41` and `0x42` are popped and stored to `UART_TX`. Byte
`0x43` stays in the buffer, byte `0x44` is dropped, bit 30 sticks, and
the callback transmits `0x43`. One overrun is recorded. The following
load has bit 31 clear and bit 30 still set until a write of bit 30.

Schedule: eight pushes fill the ring. The ninth pulses `sched_full` and
the testbench reports `RuntimeError: schedule queue full`. A non-jump
boundary does not run a callback. The next jump runs one entry, with
`heap_locked` clear.
