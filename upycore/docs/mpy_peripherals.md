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

## Blocks past the base registers

Each block decodes its own offset range and reads 0 elsewhere, so the SoC
ORs their read data. None of them has an IRQ source: the eight sources
fill the handler window (`planning/interrupts_io_plan.md` §3). Each block
has a status register that Python polls, and an `irq` output that is
recorded here for a later source.

### PWM (`0x200`)

Four channels share one counter. The counter advances once every
`PWM_PRESC + 1` clocks while any channel is enabled, and runs from 0 to
`PWM_TOP`, so a period is `(PWM_TOP + 1) * (PWM_PRESC + 1)` clocks. A
channel's output is high while the count is below its duty, so duty 0
is always low and `PWM_TOP + 1` is always high. A disabled channel is
low. Duty and top writes are shadowed and take effect when the counter
wraps to 0, so a period is never cut short.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x200` | `PWM_PRESC` | Bits 15:0. Clocks per count, minus 1 |
| `0x204` | `PWM_TOP` | Bits 15:0. Last count of a period. Reset `0xFFFF` |
| `0x208` | `PWM_EN` | Bits 3:0, one per channel. Shadowed like duty: a channel turns on or off at the next wrap. When the first one turns on the counter starts at 0; when none is on at a wrap it stops |
| `0x20C` | `PWM_COUNT` | Read-only. The counter |
| `0x210`–`0x21C` | `PWM_DUTY0..3` | Bits 16:0. High while the count is below this |

### Pin mux (`0x900`)

Four bits per pin select the pad's function. Pins 0–7 are `PINMUX0`
(`0x900`), pins 8–15 `PINMUX1` (`0x904`), pin `i % 8` in bits
`4*(i%8)+3 : 4*(i%8)`. Reset 0: every pad is GPIO.

| Code | Function | Pad output | Pad output enable |
| --- | --- | --- | --- |
| 0 | GPIO | `GPIO_OUT` bit | `GPIO_OE` bit |
| 1–4 | PWM channel 0–3 | the channel | 1 |
| 5 | `SPI_SCK` | SCK | 1 |
| 6 | `SPI_MOSI` | MOSI | 1 |
| 7 | `SPI_MISO` | — | 0 (input) |
| 8 | `I2C_SCL` | 0 | drive low (open drain) |
| 9 | `I2C_SDA` | 0 | drive low (open drain) |
| 10 | `UART_TX` | `uart_txd` | 1 |
| 11 | `UART_RX` | — | 0 (input) |

An input function reads the lowest pad that selects it. With no pad
selected, MISO reads 0, SCL and SDA read 1 (the bus pull-ups), and the
UART receiver reads the dedicated `uart_rxd` pin. `GPIO_IN` keeps its
own input (`gpio_in`, sampled while `gpio_in_en`), so the GPIO traces do
not depend on the mux. The pad view is `pad_out`, `pad_oe`, and `pad_in`.

### SPI controller (`0x300`)

Mode 0–3, 8-bit frames MSB first, full duplex. Each byte taken from the
TX FIFO is shifted out while a byte is shifted in, and the received byte
joins the RX FIFO; a byte that arrives with the RX FIFO full is dropped
and sets the overrun bit. Chip select is a GPIO.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x300` | `SPI_CTRL` | Bit 0 enable, bit 1 CPOL, bit 2 CPHA, bits 23:8 the half-period divider: SCK holds each level for `DIV + 1` clocks |
| `0x304` | `SPI_DATA` | A store pushes a byte into the TX FIFO (dropped when full). A load pops the RX FIFO: bit 31 valid, bits 7:0 the byte |
| `0x308` | `SPI_STATUS` | Bits 4:0 TX level, bits 12:8 RX level, bit 16 busy (a byte on the wire or queued), bit 17 TX empty, bit 18 RX ready, bit 19 overrun (sticky) |
| `0x30C` | `SPI_IRQEN` | Bit 0 TX empty, bit 1 RX ready: the block's `irq` output |

A store to `SPI_STATUS` with bit 19 set clears overrun; other bits ignore stores. FIFO depth is
`SPI_FIFO_DEPTH`, default 8. CPOL is SCK's idle level. With CPHA 0 the
first edge samples and MOSI changes on the second; with CPHA 1 MOSI
changes on the first edge and the second samples.

### I2C controller (`0x400`)

Commands run one at a time from `I2C_CMD`. SCL and SDA are open drain:
the block drives a line low or releases it, and reads it back. After it
releases SCL it waits for the line to read high, so a target may stretch
the clock. A stretch longer than `I2C_TIMEOUT` clocks stops the command
with the timeout bit.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x400` | `I2C_DIV` | Bits 15:0. Clocks per quarter SCL period, minus 1 |
| `0x404` | `I2C_CMD` | A store starts a command. Bits 3:0: 1 START (a repeated start when the bus is already held), 2 STOP, 3 WRITE bits 15:8, 4 READ (bit 16: send NACK instead of ACK) |
| `0x408` | `I2C_STATUS` | Read-only. Bit 0 busy, bit 1 the last WRITE saw NACK, bit 2 timeout (sticky until the next START), bit 3 the bus is held (after START, before STOP), bits 15:8 the last byte READ |
| `0x40C` | `I2C_TIMEOUT` | Clocks a stretch may last. Reset `0x0010_0000` |
| `0x410` | `I2C_CTRL` | Bit 0 enable. Disabled, both lines are released |

### WDT (`0x500`)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x500` | `WDT_LOAD` | Ticks before the reset. Writable until the watchdog starts; reset 0 |
| `0x504` | `WDT_CTRL` | Writing bit 0 starts it and loads the counter from `WDT_LOAD`. Once started it cannot be stopped; later writes are ignored. Reads bit 0 started |
| `0x508` | `WDT_KICK` | Writing `0x6B1D_F00D` reloads the counter from `WDT_LOAD`. Any other value is ignored |
| `0x50C` | `WDT_COUNT` | Read-only. Ticks left |

The counter decrements on each tick while started. The tick that takes it
to 0 pulses `wdt_reset` to the reset controller (SYS block), so with no
kick the reset comes `WDT_LOAD` ticks after the start; a start with
`WDT_LOAD` 0 resets on the next tick. `machine.WDT(timeout=ms)` loads
`timeout` ticks (a tick is a millisecond unless the testbench drives it).

### SYS block (`0x600`)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x600` | `SYS_FREQ` | Read-only. The system clock in Hz, the `SYS_FREQ_HZ` parameter (default 48 000 000). `machine.freq()` |
| `0x604` | `SYS_STRAP` | Read-only. The boot straps, sampled at reset from `strap_i`. Bit 0: the tick comes from `timer_step` (the testbench), so `_boot` leaves `TIMER_PRESC` at 0. Bits 2:1: console (0 sim console, 1 UART, 2 USB CDC). Bit 3: run the REPL after `__main__` |
| `0x608` | `SYS_RESET_CAUSE` | Read-only. `PWRON_RESET` 1, `HARD_RESET` 2, `WDT_RESET` 3, `SOFT_RESET` 5 (the `machine` constants) |
| `0x60C` | `SYS_RESET` | Writing `0x0B007ED0 | k` resets the system: `k` 0 hard (`machine.reset()`), 1 soft (`machine.soft_reset()`). Other values are ignored |
| `0x618` | `SYS_CONSOLE` | Bits 1:0, where the console goes: 0 the sim console, 1 the UART, 2 USB CDC (the coprocessor; until it exists, 2 reads back but output stays on the sim console). Reset 0. `_boot` writes strap bits 2:1 here. See Console |
| `0x610`, `0x614` | `SYS_UID0`, `SYS_UID1` | Read-only. The 64-bit unique id, the `SYS_UID` parameter, low word first. `machine.unique_id()` returns the 8 bytes, most significant first |

When bit 0 of `SYS_STRAP` is clear, `_boot` writes `TIMER_PRESC = SYS_FREQ / 1000`,
so a tick is one millisecond. Only power-on (the `rst_n` pin) clears the
reset cause; a system reset keeps the straps.

The reset controller is in this block, on the power-on reset. A system
reset (`SYS_RESET` or `wdt_reset`) records the cause, then holds every
other block in reset (`sys_rst_n` low: the core, the collector, the
memory controller, the IRQ block, and the peripherals) for
`MPY_SRAM_WORDS` clocks while it zeroes SRAM and its tags, one word a
clock. The firmware relies on SRAM reading zero at power-up (empty
sysroot slots, `A_FREE` tags), so the scrub gives a system reset the same
start. Then it releases `sys_rst_n` and the hart boots the flash image
again. Soft and hard reset differ only in the cause.

### ADC (`0x800`)

A register interface for an external converter; the analog part is a
behavioral model in the testbench.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x800` | `ADC_CTRL` | A store with bit 8 set starts a conversion of channel bits 3:0; ignored while busy. Reads the last channel in bits 3:0 |
| `0x804` | `ADC_DATA` | Read-only. Bit 31 valid (a conversion finished since the last start), bits 15:0 the result, left-aligned to 16 bits |
| `0x808` | `ADC_STATUS` | Read-only. Bit 0 busy |

The converter port is `adc_start` (one clock, with `adc_chan`), then
`adc_done` for one clock with the 12-bit `adc_code` some clocks later.
`ADC_DATA` holds `adc_code << 4`. The testbench converter
(`tb_adc_model.sv`) answers channel `c` with code
`(273 * c + 100) & 0xFFF` after 48 clocks
(`mpy_periph_model.adc_code`). `machine.ADC(id)` takes a channel number or a
`Pin` (its id is the channel); `read_u16` starts a conversion, waits, and
returns bits 15:0.

## Console

`print`, tracebacks, and `sys.stdout` / `sys.stderr` write bytes to the
sim page (`SIM_STDOUT`, `SIM_STDERR`). `mpy_soc` sends them where
`SYS_CONSOLE` says. With 1, each byte joins the UART TX FIFO through a
second push port on `mpy_periph` (`con_stb`, `con_byte`, `con_ready`); the
store is not answered until the FIFO takes it, so output waits on the
baud rate the way a hardware UART console does. In byte mode
(`UART_BAUD` 0) it leaves on `uart_tx_stb` in that cycle. stdout and
stderr share the UART. With 0 (the default, and the reset value) nothing
changes: `make test` output is the sim console. With the UART as the
console, `_boot` arms Ctrl-C (`micropython.kbd_intr(3)`) before
`__main__`, and before it halts it waits for the TX FIFO and serializer
to drain, so the last line is not lost. `kbd_intr` still arms the UART
character on the sim console when a program asks for it.

`sys.stdin` reads the console: with 1, bytes from the UART RX FIFO,
waiting in `machine.idle` while it is empty; with 0 there is no input and
a read returns `''` (end of file). `input(prompt)` writes the prompt,
then reads to a carriage return or newline and echoes what it reads
(backspace, 8 or 127, drops a character); at the end of input it raises
`EOFError`. `print(file=f)` takes only these stream objects; any other
object raises `OSError`, as in v1.29.0.
`os.dupterm` is not provided.

The testbench takes `+CONSOLE=uart` (strap bits 2:1 = 1) and then writes
the UART's TX bytes, not the sim console's, to the stdout file, so a test
on the UART console compares stdout like any other.

## Idle wake

`wake` is high on a clock with a tick, a byte accepted into the RX FIFO
(or the interrupt character), a GPIO pin-status change, or any other
source event. It does not look at `IRQ_ENABLE` or `IRQ_GIE`: `machine.idle`
returns on the event, and delivery decides what runs.

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

The module is native. `import machine` builds the functions and constants;
each class (`Pin`, `Timer`, `UART`, `PWM`, `SPI`, `I2C`, `ADC`, `WDT`, and
the class behind `mem8`/`mem16`/`mem32`) is built on its first use by the
module's `__getattr__` and then kept in the module dict. A class statement
costs tens of thousands of cycles, so the import stays near 50k cycles
however many classes there are. The operations this block backs:

| Operation | Effect |
| --- | --- |
| `Pin` / `GPIO_OUT` / `GPIO_IN` | Read-modify-write of `GPIO_OUT`. `GPIO_IN` is the pin level. `GPIO_EDGE` is the trigger |
| `Pin.irq(handler, trigger, hard)` | Writes that source's handler slot and `IRQ_HARD` |
| `Timer` compare and callback | Stores `TIMER_COUNT`, writes the timer slot, sets enable and hard |
| `UART` read, write, `irq` | Load `UART_RX`, store `UART_TX`, write the UART slot |
| `mem32` | Word load/store in this window |
| `disable_irq` / `enable_irq` | Read and write `IRQ_GIE` |
| `idle` | The hart waits. A timer that is already armed keeps its compare |
| `PWM(pin, freq, duty_u16)` | Pin mux code 1–4 (channel `pin % 4`); `PWM_PRESC`/`PWM_TOP` from `mpy_periph_model.pwm_config`, shared by all channels |
| `SPI(0, baudrate, polarity, phase)` | Pads 10–12 by default; `SPI_CTRL`; bytes through the FIFOs, eight at a time. Chip select is a `Pin` |
| `WDT(0, timeout)` / `feed` | `WDT_LOAD`, then `WDT_CTRL`; `feed` writes the key to `WDT_KICK` |
| `reset` / `soft_reset` / `reset_cause` / `unique_id` | `SYS_RESET` with k 0 or 1; `SYS_RESET_CAUSE`; `SYS_UID1` then `SYS_UID0`, big-endian |
| `ADC(id)` / `read_u16` | `ADC_CTRL` start, wait while `ADC_STATUS` busy, `ADC_DATA` bits 15:0 |
| `I2C(0, freq, timeout)` | Pads 14 (SCL) and 15 (SDA) by default; `I2C_DIV`/`I2C_TIMEOUT` from `mpy_periph_model.i2c_config` (timeout in µs). One command per byte. A NACKed address raises `OSError(ENODEV)`, a timeout `OSError(ETIMEDOUT)`; both end with STOP or the released bus. `scan` tries 0x08–0x77 |

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
