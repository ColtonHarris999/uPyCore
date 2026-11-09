# The I/O core

Status: phases 0 to 4 of [`planning/rv_io_core_plan.md`](../../planning/rv_io_core_plan.md)
(the island, the hart-side bridge, the boot section, polled board I/O, the
UART console, events on the hart, the remaining peripherals, system reset
and the REPL). USB is added by a later phase; this page grows with it. Progress and gate results:
[`planning/rv_io_core_progress.md`](../../planning/rv_io_core_progress.md).

Board I/O goes through a small RV32 core, the **I/O core**, that owns every
peripheral. The hart (mpy_core) never sees a peripheral register: it talks
to the I/O core through one memory-mapped bridge, and the two run on
independent clocks.

## The island

| Piece | Where |
| --- | --- |
| Island top: core, SRAMs, bus decode, SYS block, peripherals | `iocore/rtl/iocore_top.sv` |
| Core wrapper (CVE2 or Hazard3, one bus shape) | `iocore/rtl/iocore_cpu.sv` |
| AHB-Lite to the island bus (Hazard3 option only) | `iocore/rtl/iocore_ahb2obi.sv` |
| Timer | `iocore/rtl/iocore_timer.sv` |
| UART | `iocore/rtl/iocore_uart.sv` |
| File lists | `iocore/tools/iocore_files.py` |
| Firmware, toolchain | `iocore/sw` (`TOOLCHAIN.md`) |
| Standalone bench, UART line model | `iocore/tb/tb_iocore.sv`, `iocore/tb/tb_uart_line.sv` |
| Island side of the bridge | `iocore/rtl/iocore_bridge.sv` |
| Hart side of the bridge, the clock-domain crossing | `upycore/rtl/mpy_iobr.sv`, `upycore/rtl/mpy_async_fifo.sv` |
| Window decode, island instance, io_clk reset | `upycore/rtl/mpy_soc.sv` |
| Boot section (`IOCB`) | `upycore/rtl/mpy_boot.sv`, `upycore/tools/mpy_nand.py` |
| GPIO | `iocore/rtl/iocore_gpio.sv` |
| Hart software: board I/O firmware, `machine`, `time` | `upycore/firmware/io/`, `upycore/runtime/machine.py`, `upycore/runtime/time.py` |

### Core

**CVE2, RV32EMC, iterative multiplier** (`iocore_cpu` `CORE=0`, `MUL=0`):
machine mode only, no debug, no performance counters, `RV32MSlow`. Reset
is at `0x80`, `mtvec` at 0 in vectored mode. Hazard3 (`CORE=1`, the team's
benchmark commit `8af9929`) is kept behind the same wrapper and runs the
same firmware image; phase 0 measured both (decision D1, below).

Interrupts reach the core as two levels: the timer compare drives
`mip.MTIP`, and the SYS block's controller ORs its enabled sources into
`mip.MEIP`. Firmware reads `IRQ_PEND` to dispatch.

### Bus

The core's two ports are OBI-style: a request is taken on a clock with
`req` and `gnt` high; its response (`rvalid`, `rdata`, `err`) comes on the
next clock. A slave that cannot take a request (a UART store while its TX
FIFO is full) holds `gnt` low and the core waits. The instruction port
reads only the code SRAM; the data port reaches the data SRAM and the
peripherals. Peripheral registers are 32-bit words: a byte or halfword
access, or an address outside the map, answers with an error, which the
core takes as an access fault.

### Memory map (I/O core view)

| Address | Size | What |
| --- | --- | --- |
| `0x0000_0000` | 16 KB | Code SRAM. Vectors at 0, reset at `0x80`. Instruction port only |
| `0x0001_0000` | 8 KB | Data SRAM: `.rodata`, `.data`, `.bss`, stack at the top |
| `0x8000_0000` | 4 KB | SYS: id, debug byte, halt, interrupt controller |
| `0x8000_1000` | 4 KB | Timer |
| `0x8000_2000` | 4 KB | UART0 |
| `0x8000_3000` | 4 KB | Bridge to the hart (I/O core side) |
| `0x8000_4000` | 4 KB | GPIO |
| `0x8000_5000` | 4 KB | PWM (`iocore_pwm`) |
| `0x8000_6000` | 4 KB | SPI controller (`iocore_spi`) |
| `0x8000_7000` | 4 KB | I2C controller (`iocore_i2c`) |
| `0x8000_8000` | 4 KB | Watchdog (`iocore_wdt`) |
| `0x8000_9000` | 4 KB | ADC interface (`iocore_adc`) |
| `0x8000_A000` | 4 KB | Pin mux (`iocore_pinmux`) |

Both SRAMs are one-port macros (`bsg_mem_1rw_sync_mask_write_bit`, which
the class flow swaps for `fakeram`). While the core is held in reset, the
island's load port writes them; `mpy_boot` drives it from the boot
stream (phase 1).

### SYS (`0x8000_0000`)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `ID` | Read-only, `0x494F_4301` ("IOC", version 1) |
| `0x04` | `DEBUG` | A store's low byte goes to the bench log (`dbg_valid_o`); nothing on the chip |
| `0x08` | `HALT` | A store ends a standalone bench run with that value (`halt_o`) |
| `0x0C` | `IRQ_PEND` | Read-only, one bit per source (bit 0 UART0, bit 1 bridge, bit 2 GPIO) |
| `0x10` | `IRQ_EN` | Sources that drive `mip.MEIP` |
| `0x14` | `SCRATCH` | Read/write |
| `0x18` | `FREQ` | Read-only: io_clk in Hz (the `IOCLK_HZ` parameter; the bench's `+IO_CLK_NS` sets it in simulation) |
| `0x1C` | `CON_MODE` | Read-only: the console strap (`console_sel_i`, through two io_clk flops) |

### Timer (`0x8000_1000`)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `CYCLES` | Read-only, io_clk cycles since the core left reset |
| `0x04` | `DIV` | io_clk cycles per microsecond, minus 1 (reset: the `US_DIV_RESET` parameter, 49 for 50 MHz). A store restarts the divider |
| `0x08` | `US` | Read-only, microseconds |
| `0x0C` | `MS` | Read-only, milliseconds (every 1000 µs) |
| `0x10` | `CMP` | Compare on `US` |
| `0x14` | `CTRL` | Bit 0 enable, bit 1 pending (write 1 to clear). Pending sets on the microsecond `US` reaches `CMP`; enable and pending drive `mip.MTIP` |

### UART0 (`0x8000_2000`)

8N1, LSB first, idle high; 16-byte TX and RX FIFOs. Ported from the epic
branch's `mpy_periph` UART (the same serializer, receiver and FIFO
rules), without its byte-strobe mode.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `DATA` | A store pushes a byte to TX; while TX is full the store waits (`gnt` low). A load pops RX: bit 31 valid, bit 30 overrun, bit 29 framing error, bits 7:0 the byte |
| `0x04` | `STATUS` | Bits 7:0 RX level, 15:8 TX level, bit 16 TX busy (queued or on the wire), 17 RX full, 18 TX full, 19 RX not empty |
| `0x08` | `BAUD` | io_clk cycles per bit (below 4 counts as 4). Reset: the `BAUD_RESET` parameter |
| `0x0C` | `IRQEN` | Bit 0 RX not empty, bit 1 TX idle: the block's interrupt (`IRQ_PEND` bit 0) |
| `0x10` | `CLR` | Write bit 30 to clear overrun, bit 29 to clear the framing error |

A byte that arrives while RX is full is dropped and sets overrun. The
receiver finds the start bit's falling edge, checks it half a bit later
(a high line is a glitch), samples eight bits and the stop bit at bit
intervals; a low stop bit drops the byte and sets the framing error.

### GPIO (`0x8000_4000`)

Sixteen pins. The pad wrapper gets `gpio_o`, `gpio_oe_o`, `gpio_pu_o` and
`gpio_pd_o`, and returns `gpio_i`. The input goes through two flops and a
third register (`IN`), and the edge check compares `IN` with the second
flop, so an edge is seen on the clock it reaches `IN`. Edge rules are the
epic branch's `mpy_periph` GPIO.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `OUT` | Output levels |
| `0x04` | `SET` | A store of 1s sets those `OUT` bits |
| `0x08` | `CLR` | A store of 1s clears them |
| `0x0C` | `XOR` | A store of 1s toggles them |
| `0x10` | `OE` | Output enable per pin; reset 0, every pin an input |
| `0x14` | `PU` | Pull-up enable per pin, to the pad wrapper |
| `0x18` | `PD` | Pull-down enable per pin |
| `0x1C` | `IN` | Read-only, the synchronized pad levels |
| `0x20` | `EDGE` | Two bits per pin (pin 0 in bits 1:0): `01` rising, `10` falling, `11` both |
| `0x24` | `STATUS` | One bit per pin whose `EDGE` matched a change; write 1 to clear (an edge on that clock stays) |
| `0x28` | `IRQEN` | Pins whose `STATUS` bit raises the GPIO interrupt (`IRQ_PEND` bit 2) |

### PWM, SPI, I2C, watchdog, ADC, pin mux (`0x8000_5000`–`0x8000_A000`)

These six blocks are the epic branch's `mpy_pwm`, `mpy_spi`, `mpy_i2c`,
`mpy_wdt`, `mpy_adc` and `mpy_pinmux`, renamed `iocore_*` and moved onto
the I/O core's bus. `iocore_top` feeds each one its old MMIO offset (the
4 KB region's low byte under the old high nibble), so their register
logic is unchanged; each file's header gives the rules. Register words
(`iocore/sw/common/iocore.h`):

| Block | Registers (offset from the region base) |
| --- | --- |
| PWM | `0x00` PRESC, `0x04` TOP, `0x08` EN (4 channels), `0x0C` COUNT, `0x10`+4c DUTY. One counter for the four channels; TOP, DUTY and EN load at the wrap |
| SPI | `0x00` CTRL (bit 0 on, 1 CPOL, 2 CPHA, 23:8 the half-period divider), `0x04` DATA (TX FIFO / RX FIFO), `0x08` STATUS. Mode 0–3, 8-bit frames, MSB first; chip select is a GPIO |
| I2C | `0x00` DIV (quarter bit), `0x04` CMD (START, STOP, WRITE, READ with ACK/NACK), `0x08` STATUS, `0x0C` TIMEOUT (clock stretch limit), `0x10` CTRL |
| Watchdog | `0x00` LOAD, `0x04` CTRL (bit 0 starts), `0x08` KICK, `0x0C` COUNT; counts the timer's millisecond tick |
| ADC | `0x00` CTRL (bit 8 starts, 3:0 channel), `0x04` DATA (12-bit code, left-aligned, valid bit), `0x08` STATUS; the converter is outside the island (`adc_start_o`, `adc_chan_o`, `adc_done_i`, `adc_code_i`; a model in the bench) |
| Pin mux | `0x00`, `0x04` four bits per pad (pads 0–7, 8–15): 0 GPIO, 1–4 PWM, 5 SCK, 6 MOSI, 7 MISO, 8 SCL, 9 SDA, 10 UART TX, 11 UART RX. I2C pads are open drain |

`iocore_top` puts every access to these six blocks through a register
stage: the block sees the access a clock after the core's request, from
flops, and answers a clock after that (the core waits for `rvalid`), and
no data access is granted while one is in the stage, so a load never
reads a register older than an earlier store. Their write logic (the I2C
controller's command start, the watchdog's kick and count) from the
core's address was the island's longest path.

Two changes from the epic branch's watchdog. A KICK of the key
`0x6B1D_F00D` reloads it as before; the tick that runs it out pulses its
reset and also **stops** it, as a chip's watchdog reset clears its
watchdog (the island is not reset with the hart, so an expired watchdog
that kept running would reset the hart every tick). A KICK of the stop
key `0x5709_DEAD` stops it; the firmware sends it only for
`machine.reset()`, and the hart has no other path to it. An expiry
toggles `wdt_toggle_o`, which the bridge synchronizes into a system reset
(Reset).

## Clock domains

The hart runs on `clk_i`; the island on `io_clk_i`, an independent clock
(50 MHz in simulation, `+IO_CLK_NS`). `mpy_soc` makes the island's own
power-on reset from `rst_n_i` through two `io_clk` flops. Every signal
between the domains goes through a dual-clock FIFO (`mpy_async_fifo`,
ported from the epic branch: binary pointers one bit wider than the
depth, gray-coded across two flops each way). A level read on either
side is the synchronized view: it lags the far side by up to three of its
clocks, always in the safe direction (a writer never sees more room than
there is, a reader never sees more words). No other signal crosses: the
I/O core's run bit is a hart-domain flop that the island synchronizes
with two flops, and the state page the hart reads is a hart-side copy fed
by a FIFO.

Only the power-on reset resets the FIFOs, both sides together. Neither
the hart's soft reset nor the I/O core's reset touches them, so words in
flight survive either one.

## Bridge

### Hart side (the MMIO window, `0x4000_0000`)

`mpy_soc` decodes the window beside the simulator page, on the core-port
skid: a word-aligned access to an implemented offset is a local access,
taken only when none of the core's memory accesses is waiting for its
ack (`c_out`) and the bridge's FIFOs have room (`stall_o`, a flop).
Loads answer on the next clock through the simulator page's answer
flops; stores are posted. Every other address in the window (misaligned,
or an offset not in the tables below) goes to `mpy_mem`, which answers
with the unaligned or bus fault, the same fault path as any memory
access. `mpy_mem` itself is unchanged. Fetch, the collector and the copy
engine never address the window; its words are untagged and never a GC
root.

| Offset | Name | Rule |
| --- | --- | --- |
| `0x000` | `CMD` | A store pushes the word to CMD (32 words). A store while CMD has no room waits in the skid (the core's `m_busy_i`); nothing is dropped. Loads read 0 |
| `0x004` | `RSP` | A load pops RSP (16 words); 0 when empty. `STATUS` bit 31 says whether there was a word |
| `0x008` | `STATUS` | Bits 5:0 CMD level, 12:8 RSP level, bit 16 CMD full, 17 CON full, 18 CON_RX not empty, bits 30:24 CON level, bit 31 RSP not empty. Levels are the synchronized view |
| `0x00C` | `EVT` | Pending event bits (Events). A store of 1s clears those bits; a bit set on the same clock stays set |
| `0x010` | `EVT_EN` | Bits that may raise `evt_pend` |
| `0x014` | `EVT_SET` | A store of 1s sets those bits from the hart |
| `0x018` | `EVT_MASK` | Bit 0 masks `evt_pend` (a callback is running); bit 1 is `machine.disable_irq` |
| `0x01C` | `IOC_CTRL` | Read-only. Bit 0: the I/O core runs. Bit 1: the boot stream had its section |
| `0x020` | `CON_RX` | A load pops one console input byte: bit 31 valid, bits 7:0 the byte |
| `0x024` | `CON_MODE` | Read-only: the console strap (`console_sel_i`: 0 `sim`, 1 `uart`, 2 `usb`) |
| `0x028` | `CMD_SENT` | Read-only: CMD words pushed since power-on (the I/O core's `SEQ` page word counts the ones it has finished) |
| `0x02C` | `RESET_CAUSE` | Read-only: why the hart domain last reset, `machine`'s numbers: 1 power on, 2 `machine.reset`, 3 the watchdog, 5 `machine.soft_reset` |
| `0x030` | `SYS_RESET` | A store of `0x0B007ED0 \| kind` (the key in bits 31:4) resets the hart domain: kind 0 hard, 1 soft. Other values are ignored |
| `0x034` | `KEEP` | A word that survives a system reset (the REPL keeps its mode here); 0 at power on |
| `0x800`–`0x87C` | State page, I/O core words | 32 words the I/O core writes and the hart reads (stores are ignored) |
| `0xC00`–`0xC1C` | State page, hart words | 8 words the hart writes (and reads back) and the I/O core reads |

Each I/O core page word arrives through UPD as a whole word, so a load
never sees half of one; a word updated twice in a row may skip the first
value. `evt_pend` is the flop `|(EVT & EVT_EN) && EVT_MASK == 0`, the
only signal the I/O work gives `mpy_core`.

### I/O core side (`0x8000_3000`)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x000` | `CMD` | A load pops the head CMD word (0 when empty) |
| `0x004` | `CMD_LEVEL` | Words in CMD |
| `0x008` | `RSP` | A store pushes a word to RSP; while RSP is full the store waits |
| `0x00C` | `EVT` | A store's bits 15:0 set those `EVT` bits on the hart; waits while EVT's FIFO (4) is full |
| `0x010` | `CON` | A load pops a console output byte: bit 31 valid, bit 8 stderr, bits 7:0 |
| `0x014` | `CONRX` | A store pushes a console input byte for the hart's `CON_RX`; waits while full (16) |
| `0x018` | `STATUS` | Bit 0 CMD not empty, 1 CON not empty, 2 RSP full, 3 CON_RX full, 4 EVT full, 5 UPD full, 6 a hart word is in flight; bits 21:16 CMD level, 30:24 CON level |
| `0x01C` | `IRQEN` | Bit 0 CMD not empty, bit 1 CON not empty, bit 2 a hart word changed: the bridge's interrupt (`IRQ_PEND` bit 1) |
| `0x020` | `DN_NEW` | One bit per hart page word that changed since the last read; the read clears them |
| `0x800`–`0x87C` | State page | A store pushes that word to the hart (UPD, 4 deep; waits while full) |
| `0xC00`–`0xC1C` | Hart words | The hart's page words, as they arrive |

### Commands

A CMD word is a channel in bits 31:24 and a payload in bits 23:0; a
multi-word command gives its length in its first word. The I/O core's
loop (`iocore/sw/fw/main.c`, numbers in `fw/proto.h`) runs each command
and answers synchronous ones in RSP, in order.

| Channel | Name | Payload | Answer |
| --- | --- | --- | --- |
| `0x01` | `SYS` | bits 23:16 op: `0x01` PING, `0x02` FREQ, `0x03` UID, `0x04` RESET (bit 0: also stop the watchdog) | PING: the protocol version (5); FREQ: io_clk in Hz; UID: two words, high first; RESET: 0, once the peripherals are back to their reset state |
| `0x02` | `ECHO` | anything | the same word |
| `0x03` | `EVT` | bits 15:0 | raises those events (a bridge test) |
| `0x04` | `PAGE` | bits 4:0 a page word; the next CMD word is its value | the CMD word, after the page word is pushed (a bridge test) |
| `0x05` | `DNRD` | bits 2:0 a hart word | that word as the I/O core sees it |
| `0x06` | `KBD` | bit 8 armed, bits 7:0 the console's interrupt character | — |
| `0x10` | `PIN_INIT` | bits 4:0 pin, 7:5 mode (0 IN, 1 OUT, 2 OPEN_DRAIN), 9:8 pull (0 none, 1 up, 2 down), bit 10 set the value, bit 11 the value | — |
| `0x11` | `PIN_WRITE` | bits 4:0 pin, bit 8 the value | — |
| `0x12` | `PIN_TOGGLE` | bits 4:0 pin | — |
| `0x13` | `PIN_IRQ` | bits 4:0 pin, 9:8 edges (1 rising, 2 falling, 3 both, 0 off) | — |
| `0x20` | `UART_INIT` | bits 3:0 id; the next word is the baud rate | the rate the divider gives |
| `0x21`–`0x23` | `UART_TX1`–`TX3` | one to three bytes, the first in bits 7:0 | — |
| `0x28` | `UART_RX` | bits 7:0 the most bytes wanted | the count k, then ceil(k/3) words of three bytes |
| `0x29` | `UART_DEINIT` | | — |
| `0x2A` | `UART_IRQ` | bits 15:0 the triggers (`0x20` TXIDLE, `0x40` RXIDLE, rp2's values) | — |
| `0x30` | `TIMER_INIT` | bits 1:0 id, bit 2 periodic, bit 3 raise `TIMER` on each expiration; the next word is the period in µs | — |
| `0x31` | `TIMER_DEINIT` | bits 1:0 id | — |
| `0x14` | `PIN_FUNC` | bits 4:0 pin, 11:8 the pad function (pin mux numbers) | — |
| `0x40` | `PWM_CFG` | the next word: 31:16 prescaler, 15:0 top (all channels) | — |
| `0x41` | `PWM_DUTY` | bits 1:0 channel; the next word the duty compare | — |
| `0x42` | `PWM_EN` | bits 3:0 the channels on | — |
| `0x50` | `SPI_INIT` | bit 0 CPOL, 1 CPHA; the next word the half-period divider | — |
| `0x51` | `SPI_XFER` | bits 7:0 n bytes, bit 8 answer the bytes read; ceil(n/3) words of bytes follow | with bit 8, ceil(n/3) words read |
| `0x52` | `SPI_DEINIT` | | — |
| `0x60` | `I2C_INIT` | the next words: the quarter-bit divider, the timeout in clocks | — |
| `0x61` | `I2C_XFER` | bits 6:0 address, 7 read, 15:8 n bytes, 16 START, 17 STOP, 18 NACK the last byte read; a write's ceil(n/3) words follow | status (0, -19 ENODEV, -110 ETIMEDOUT, or for a write n minus the bytes acked), then a read's ceil(n/3) words |
| `0x62` | `I2C_DEINIT` | | — |
| `0x70` | `ADC_READ` | bits 3:0 channel | the code, left-aligned to 16 bits |
| `0x80` | `WDT_START` | the next word: the timeout in ms | — |
| `0x81` | `WDT_FEED` | | — |

A word with channel `0x80` or above has bit 31 set, which a small int
cannot hold in its payload, so `machine.py` writes those words as the
negative ints they are (`-0x80000000` for `0x8000_0000`).

An open-drain pin drives its pad only while its output is 0: `PIN_INIT`,
`PIN_WRITE` and `PIN_TOGGLE` keep its `OE` bit the inverse of its `OUT`
bit.

### State page

Words the I/O core writes (`0x800 + 4*i` in the hart's window):

| Word | Name | Contents |
| --- | --- | --- |
| 0 | `VERSION` | `0x494F_0003`: protocol version 3 |
| 1 | `PIN_IN` | The pin levels (`GPIO IN`), pushed when they change |
| 2 | `PIN_FLAGS` | Two bits per pin: the edges seen since its `PIN_IRQ` (1 rising, 2 falling) |
| 3 | `MS` | The island timer's millisecond count (mpy_iobr's tick crossing, not UPD) |
| 4 | `US` | Its microsecond count (the same) |
| 5 | `CYCLES` | io_clk cycles, pushed each millisecond |
| 6 | `UART0` | Bits 15:0 bytes waiting in the RX ring, 27:16 room in the TX ring, bit 31 TX busy (queued or on the wire) |
| 7 | `SEQ` | CMD words the I/O core has finished |
| 8–11 | `TIMER0`–`3` | Expirations of each software timer |
| 12–15 | `PIN_CNT` | An 8-bit count of armed edges per pin, four pins a word |
| 16 | `UART0_EV` | Bits 7:0 RXIDLE events, 15:8 TXIDLE events, 23:16 the last triggers |

`SEQ` orders commands against state-page reads: before a read whose
answer depends on earlier commands (`Pin.value()`, `UART.any()`,
`txdone()`), `_io.page` waits until `SEQ` equals the bridge's
`CMD_SENT`. A read with nothing in flight costs one more word load.

Event bits the I/O core raises (the hart's `EVT`):

| Bit | Name | When |
| --- | --- | --- |
| 0 | `SOFT` | `micropython.schedule` (the hart sets it with `EVT_SET`) |
| 1 | `KBD` | The console's armed interrupt character arrived (it is not passed on as a byte) |
| 2 | `UART0` | An armed `UART.irq` trigger |
| 3 | `TIMER` | A timer with a callback expired |
| 4 | `PIN` | An armed pin edge |

## Boot

The boot stream (`mpy_boot.md`) may carry the I/O core's firmware after
the image: `IOCB` (`0x4243_4F49`), the code word count, the data word
count, then the code words and the data words. `mpy_boot` sends each as
`{data SRAM, index, word}` through `mpy_iobr`'s LD FIFO to the island's
load port, which writes it into the island's SRAM while the I/O core is
in reset. When boot is done, the section was there and LD has drained,
`mpy_soc` sets the run flop (`IOC_CTRL` bit 0); the island synchronizes
it and releases the core. The hart starts at the same time, so CMD words
it sends before the I/O core is up wait in CMD. A stream with no section
(the next word after the image is not `IOCB`) leaves the I/O core in
reset and `IOC_CTRL` at 0; a count beyond the island's SRAMs raises
`boot_err_o`. The hart's SRAM, the image load and the collector's table
clear are unchanged, so a stream without the section is the boot every
existing test runs, and the hart's cycle counter still starts at its
first instruction.

`mpy_build.py` adds the section (from `make -C iocore/sw`, `APP=fw`) to
images that use board I/O: in the simulation shortcut as `+IOC_CODE` and
`+IOC_DATA`, over SPI in the `.nand.bin` that `mpy_nand.py --iocore`
writes.

## Hart software

Images that use board I/O get more firmware; every other image is
byte-identical to one built without the I/O work (gate G4).
`mpy_build.io_imports()` decides: a program (or its frozen modules)
that imports `machine` or `_io` is a board I/O program. For those:

- the firmware is `FW_ORDER` followed by `upycore/firmware/io/`
  (`IO_FW_ORDER`), built separately in `build/mpy/fw_io`;
- `machine` (`upycore/runtime/machine.py`) is frozen in, like the other
  runtime modules;
- the boot stream carries the I/O core's section.

`upycore/firmware/io/io.py` defines the native module `_io`: `_io.rd(off)`
is one word load at `0x4000_0000 + off` (a signed 32-bit int, as
`_peek32` returns), `_io.wr(off, w)` one word store (`_st`, which stores
the low 32 bits of any int). It also defines `_poke32(addr, w)`. That is
not a new core native: `_st` already stores a raw word, and the rule for
this work allows no other `mpy_core` change. `machine.mem32` reaches the
bridge window only; like `extmod/machine_mem.c` it raises `ValueError`
for an address not aligned to 4 bytes, and here also for one outside the
window.

## Firmware

`iocore/sw/fw` is the production image: one loop. Each pass runs the
next command if CMD has one (and then pushes `SEQ`), then `service()`:
moves UART0's hardware FIFO into a 256-byte RX ring (a full ring drops
the byte), moves console bytes (below), moves the 256-byte TX ring into
the UART's hardware FIFO, runs four software timers on the microsecond
counter, and pushes the state-page words that changed. A command that
waits (for its next word, or for room in RSP or the TX ring) calls
`service()` while it waits, so the UART and the console never stall
behind it. At start the firmware sets the timer's divider from `FREQ`
and UART0 to 115200 8N1 (the console's rate and `machine.UART`'s
default), so bytes that arrive before `machine.UART()` are kept. Phase 2
polls; interrupts and `wfi` come with the events of phase 3. The image is
2.6 KB of code. Events (phase 3): the loop also counts latched pin edges
(the GPIO block holds them in `STATUS`, so a short pulse is not lost),
raises `TIMER` for timers with a callback, raises `UART0` for RXIDLE (bytes,
then 20 bit times quiet) and TXIDLE, and turns the console's interrupt
character into `KBD`. Ctrl-C is armed from the start on a `uart` or `usb`
console, as `pyexec` arms it for a script.

`make -C iocore/sw APP=<dir>` builds `build/iocore/<dir>/code.hex` and
`data.hex` (one 32-bit word a line). `.vectors` and `.text` go in code
SRAM; `.rodata` and `.data` in data SRAM at their run addresses, loaded
by `mpy_boot`, so `crt0.S` copies nothing and only clears `.bss`. The
link fails past 16 KB code or 8 KB data, or past the plan's budget of
14 KB code and 7 KB data with a 1 KB stack.

## machine and time

`upycore/runtime/machine.py` and `time.py` are frozen into images that
import them (with `time` whenever `machine` is). They follow MicroPython
v1.29.0's signatures:

| API | How |
| --- | --- |
| `Pin(id, mode=-1, pull=-1, *, value=None)`, `init`, `value`, `__call__`, `on`, `off`, `high`, `low`, `toggle`, `mode`, `pull` | `PIN_*` commands; `value()` reads `PIN_IN` after `_fence`. Ids 0–15; modes `IN`, `OUT`, `OPEN_DRAIN`; pulls `PULL_UP`, `PULL_DOWN` |
| `UART(0, baudrate=115200, bits=8, parity=None, stop=1, *, timeout=0, ...)`, `init`, `deinit`, `any`, `read`, `readinto`, `readline`, `write`, `flush`, `txdone` | `UART_*` commands, three bytes a word each way; `any()` and `txdone()` read `UART0`. 8N1 only (anything else is `ValueError`). `read()` with nothing waiting returns `None` |
| `Timer(id, *, mode, freq, period, callback, hard=True)`, `init`, `deinit` | `TIMER_*` commands; ids 0–3; the callback gets the Timer (Events on the hart) |
| `Pin.irq(handler=None, trigger=IRQ_FALLING\|IRQ_RISING, hard=False)` | `PIN_IRQ`; returns the irq object (`flags()`, `trigger()`); `irq(None)` disarms |
| `UART.irq(handler, trigger, hard=False)` | `UART_IRQ`; `IRQ_RXIDLE` (64) and `IRQ_TXIDLE` (32), rp2's values |
| `disable_irq()`, `enable_irq(state)` | `EVT_MASK` bit 1 |
| `mem32` | The bridge window (above) |
| `freq()` | The hart's clock, 100 MHz (a constant) |
| `idle()` | `_wfe` for an event or 1 ms |
| `time.ticks_ms`, `ticks_us`, `ticks_cpu`, `ticks_add`, `ticks_diff` | `MS` and `US` from the page, `ticks_cpu` the hart's cycle counter (`_io.cpu()`); period 2^30, `extmod/modtime.c`'s arithmetic and `OverflowError` |
| `time.sleep`, `sleep_ms`, `sleep_us` | `_wfe` for the time left on `US`, then again, so a sleep is never shorter than asked; each pass is a soft point, so callbacks run during a sleep |
| `time.time`, `time_ns` | Seconds and nanoseconds since the I/O core started (there is no RTC) |

| `PWM(dest, *, freq, duty_u16, duty_ns, invert)`, `init`, `deinit`, `freq`, `duty_u16`, `duty_ns` | `PIN_FUNC`, `PWM_*`. Pads 0–3 are channels 0–3 (the pin mux's PWM functions); one counter, so every channel shares the last `freq` |
| `SPI(0, baudrate, *, polarity, phase, bits=8, firstbit=MSB, sck, mosi, miso)`, `init`, `deinit`, `read`, `readinto`, `write`, `write_readinto` | `SPI_*`, three bytes a word; pads 10 SCK, 11 MOSI, 12 MISO (the bench's flash has CS on 13, a `Pin`) |
| `I2C(0, *, scl, sda, freq=400000, timeout=50000)`, `scan`, `writeto`, `readfrom`, `readfrom_into`, `writeto_mem`, `readfrom_mem`, `readfrom_mem_into` | `I2C_*`; pads 14 SCL, 15 SDA. A missing device is `OSError(ENODEV)`, a stretch past the timeout `OSError(ETIMEDOUT)`; `writeto` returns the bytes acked |
| `ADC(id)`, `read_u16` | `ADC_READ`; channels 0–15 |
| `WDT(id=0, timeout=5000)`, `feed` | `WDT_START`, `WDT_FEED`; it cannot be stopped |
| `reset()`, `soft_reset()`, `reset_cause()`, `unique_id()` | Reset (below); `unique_id` is SYS `UID`, 8 bytes |

`machine.Pin`, `UART` and `Timer` raise `OSError(ENODEV)` (19) when the
I/O core is not running (`IOC_CTRL` bit 0 clear).

## Reset

`mpy_soc` has two resets. `pwr_n`, the power-on reset (`rst_n_i` through
two flops), resets everything. `por_n`, the hart domain's reset, is a
flop: low at power on, and for 32 clocks after a system reset request
(the bridge's `sys_reset_o`, one clock). It resets the SRAM clear, the
boot loader, the collector and the core, so the image boots again; the
I/O island, the bridge's FIFOs, `RESET_CAUSE` and `KEEP` are on `pwr_n`
and carry on, as a separate I/O chip would. On a second boot the boot
stream's I/O core section is not written again into the running island
(`ld_push_i` is gated by `ioc_run`).

Three things request a system reset: `machine.reset()` (`SYS_RESET` kind
0), `machine.soft_reset()` (kind 1) and the watchdog's expiry. Before the
store, the firmware (`_io.reset`) sends `SYS` `RESET`: the I/O core stops
its timers, pin interrupts and UART triggers, returns the pads to inputs
without pulls, the pin mux to GPIO, and turns PWM, SPI and I2C off, as
MicroPython's soft reset deinitializes them (ports/rp2/main.c); for
`machine.reset()` it also stops the watchdog. A soft reset leaves the
watchdog running, as on a chip. UART0 keeps its rings and rate, since the
console may be on it. Then the console drains (CON empty, the UART idle)
and the store resets the hart.


## Events on the hart

Planning §5 as built. The only `mpy_core` changes are these three:

- **Soft points.** A flop, `soft_pt`, is set when `JUMP`,
  `POP_JUMP_IF_TRUE/FALSE`, `JUMP_IF_TRUE/FALSE_OR_POP`, `POP_EXCEPT_JUMP`
  or `UNWIND_JUMP`'s last jump retires (taken or not) in a frame that is
  not firmware, and cleared in `S_DEC`. `S_FETCH` gains one arm after its
  fault, spill and reload arms: `soft_pt && evt_q` (`evt_q` is
  `evt_pend_i` through one flop) goes to `S_IRQ`, which calls the hook
  `_irq_dispatch` with return kind `DISCARD` (the ordinary call path; the
  hook frame is firmware, so it adds no traceback line) and comes back to
  `S_FETCH` with `pc` unchanged. A pending async ALU result is written back
  first, by `S_FETCH`'s existing write-back arm. With nothing pending the
  arm is never taken, so no opcode takes another cycle.
- **`_wfe(cycles)`**, a native: the core waits in `S_WFE` until `evt_q`
  (returns `True`) or the timeout (returns `False`). `time.sleep*` and
  `machine.idle()` use it; the plan's third wake source, a tick change,
  is not needed, since the sleep computes its timeout from the tick.
- **The heap lock.** `_hlock` and `_hunlock` (natives) move a 15-bit depth
  that wraps like `gc_lock_depth`; `_hunlock` returns the new depth. `S_AL`
  goes to `S_HLK` while the depth is not 0: a soft allocation (a
  traceback entry) fails quietly, any other raises
  `MemoryError("memory allocation failed, heap is locked")`, the fixed
  message the image already carries; its object is the one allocation
  let past the lock (`hl_skip`), or the emergency `MemoryError` if even
  that fails.

The new natives and the hook are left out of images without the board
I/O firmware (`mpy_abi.IO_NATIVES`, `OPTIONAL_HOOKS`; the linker drops a
trailing optional hook nobody defines), so those images are unchanged.
To keep the core's register groups as they were (gate G3), the dispatch
call and the locked-heap raise each have their own state rather than
logic in the existing `S_FETCH` and `S_AL` arms, and the call enters
`S_HOOK` directly, as boot does, since it has no arguments.

`_irq_dispatch` (`upycore/firmware/io/irq.py`):

1. Sets `EVT_MASK` bit 0, reads `EVT & EVT_EN` and clears those bits.
2. `KBD`: clears the mask and raises `KeyboardInterrupt`, which the
   ordinary unwinder carries into the interrupted frame (the hook frame
   is a callee at the boundary).
3. `PIN`, `TIMER`, `UART0`: compares the state page's counts with the
   counts each handler has seen; each new event schedules a soft handler
   (dropped if the queue is full, as `mp_sched_schedule` drops it) or
   runs a hard one at once with the heap locked. An exception from a
   hard handler prints `Uncaught exception in IRQ callback handler` and
   the exception on stderr and disables the handler
   (`shared/runtime/mpirq.c`). Several pin edges before the handler runs
   give one call; a timer gives one per expiration, up to four at a time.
4. Runs at most one scheduled callback (`py/scheduler.c`), protected: an
   exception is printed on stdout (`mp_call_function_1_protected`) and
   the program goes on.
5. Sets `SOFT` again if the queue is not empty, and clears the mask.

The handler table and the queue are ordinary heap objects in a dict
reachable from sysroot word 28, so the collector needs no mirror. A
traceback of an exception from a hard handler has no frames (none can be
recorded with the heap locked), and, as `py/obj.c` does, then prints no
`Traceback` header.

The `_io` helpers `machine` uses (`cmd`, `cmd2`, `req`, `req2`, `page`,
`fence`, `uart_rx`, `set_handler`, `evt_enable`, `disable_irq`,
`enable_irq`, `wfe`) are firmware functions: no soft point falls inside
firmware, so a callback never runs halfway through a command and its
answer, as one never runs halfway through a C function on MicroPython.

`micropython.schedule`, `heap_lock`, `heap_unlock` and `kbd_intr` are the
board I/O firmware's in images that have it; `mpy_build.io_imports`
gives it to any program that names them. The schedule queue holds 8
(rp2's depth; the ninth with eight waiting raises `RuntimeError("schedule
queue full")`). `machine.disable_irq()` sets `EVT_MASK` bit 1 and returns
whether events were enabled; `enable_irq(state)` restores it. The boot of
an image with the board I/O firmware sets `EVT_EN` bits 0 and 1, so the
schedule and Ctrl-C are live from the first instruction of the program.

Deviations from MicroPython:

- **`hard=True` (decision D2).** A hard handler runs at the next soft
  point (a loop jump), like a soft one, with the heap locked so an
  allocation still raises; on a microcontroller it runs inside the
  interrupt within microseconds. Here it waits tens to hundreds of hart
  cycles, because delivery at any instruction needs a per-opcode check
  that would slow every program. Work that needs microseconds belongs in
  the I/O core's C handlers.
- Ctrl-C, callbacks and the real schedule exist only in images with the
  board I/O firmware: a program that uses none of `machine`, `time`, the
  console streams or `micropython`'s event functions has the base
  firmware, which has no `_irq_dispatch`, so nothing enables an event for
  it. (Such a program is not interrupted by Ctrl-C on the UART console;
  the REPL image, phase 4, has the board I/O firmware.)
- `Pin.irq` coalesces edges that arrive before the handler runs into one
  call (MicroPython schedules the pending handler once too, but a hard
  handler there runs once per edge).

## Console

The strap `console_sel_i` (`+CONSOLE=sim|uart|usb` on the bench) picks
the console. Output: the firmware writes console bytes as always (`_wr`
and `_we`, posted stores to `SIM_STDOUT` and `SIM_STDERR`), so the hart
spends the same cycles in every mode. With the `uart` strap `mpy_soc`
sends those bytes into the bridge's CON FIFO instead of to the `con_*`
port, and the I/O core moves them into UART0's TX ring; when CON is full
the next store waits, as `print` waits on a slow UART. stdout and stderr
share the UART, in order. The I/O core cooks the output as MicroPython's
console does (`mp_hal_stdout_tx_strn_cooked`): `\n` goes out as `\r\n`,
except after a `\r`, so the REPL's and `input()`'s own `\r\n` line ends
pass unchanged. (MicroPython writes those raw; the hart has one output
path, so a program's `print("a\r\n")` sends `a\r\n` here where
MicroPython sends `a\r\r\n`.) Phase 2 sent `\n` as is; the UART-console
goldens changed with phase 4.

Input: the I/O core moves UART0's received bytes into the hart's CON_RX
(with the `uart` strap; then `machine.UART(0)` sees none). Programs that
call `input()` or use `sys.stdin`, `sys.stdout` or `sys.stderr` get the
console firmware (`upycore/firmware/io/console.py`), which adds the three
streams to `sys` (native modules with `read`, `readline`, `write`,
`flush`) and replaces `input()`: the prompt, then line editing as in
`shared/readline/readline.c` (printable bytes echo, Enter is CR, LF or
one CR LF pair and echoes CR LF, backspace echoes `\b\x1b[K`, Ctrl-C
raises `KeyboardInterrupt`, Ctrl-D on an empty line `EOFError`, escape
sequences are dropped). With the `sim` strap there is no input, and
`input()` raises `EOFError` as at the end of a stream. The armed
interrupt character raises `KeyboardInterrupt` at the next soft point.

## REPL

A REPL image (`mpy_build.build_program(repl=True)`, `repl = true` in the
hardware-suite manifest) has the board I/O firmware, the REPL
(`upycore/firmware/io/repl.py`, which replaces `_boot`) and the on-device
compiler. With the `sim` strap it runs its program and halts, as every
image does. With the `uart` (or `usb`) strap it does what
`ports/rp2/main.c` does in MicroPython v1.29.0: it runs the program (the
image's main.py, empty in the REPL tests), prints an uncaught exception,
and runs the REPL; `SystemExit` or Ctrl-D at an empty prompt is a soft
reboot (`MPY: soft reboot`, then `machine.soft_reset()`), and the REPL
comes back in the mode it was in, kept in the bridge's `KEEP` word.
After a soft reboot from the raw REPL the program does not run, as on
rp2.

The REPL follows `shared/runtime/pyexec.c` and
`shared/readline/readline.c`:

- **Friendly REPL.** The banner `MicroPython 062cf49b48 on 2026-10-14;
  upycore` (`sys.version`'s name and `sys.implementation._machine`) and
  `Type "help()" for more information.`, then `>>> `. A line is compiled
  in `single` mode, so an expression's value is printed by
  `__repl_print__` (a builtin only REPL images have). A line that
  `mp_repl_continue_with_input` says is incomplete (a compound statement,
  open brackets or triple quotes, a trailing backslash) reads more lines
  at `... ` with auto-indent until an empty one. Ctrl-A changes to the
  raw REPL, Ctrl-B prints the banner again, Ctrl-C cancels the line,
  Ctrl-D soft-reboots, Ctrl-E is paste mode. Line editing is
  readline's at the end of the line: printable bytes echo, backspace
  erases one character (four inside an indent) with `\b\x1b[K`, tab
  indents after a space. History, the arrow keys (their escape sequences
  are dropped), tab completion and the emacs keys are not implemented.
- **Raw REPL** (what `mpremote` drives). `raw REPL; CTRL-B to exit` and
  `>`; bytes collect without echo until Ctrl-D, then `OK`, the output,
  `\x04`, the exception if any, `\x04`, `>`. Ctrl-D on an empty
  command soft-reboots; Ctrl-B returns to the friendly REPL; Ctrl-C
  clears the command. Raw-paste mode (`\x05A\x01`) answers `R\x01`, a
  128-byte window (`\x80\x00`) and `\x01`, then grants a window with
  `\x01` after every 128 bytes, as `mp_reader_stdin` does; the source is
  read to Ctrl-D before it is compiled (MicroPython compiles while it
  reads, which only changes when a syntax error is reported).
- **Ctrl-C.** The interrupt character is armed only while a command
  runs (`mp_hal_set_interrupt_char`): at the prompt Ctrl-C is a byte the
  REPL reads. When a command finishes the REPL disarms it, waits for the
  I/O core to take the command (`_io.fence`), and clears a `KBD` event
  that arrived meanwhile.
- **Exceptions** print on stdout (`mp_plat_print`), the traceback with
  `File "<stdin>"`.

Each command is compiled on the hart by the frozen compiler, which takes
about 15 million hart cycles for a short line (0.15 s at 100 MHz); the
REPL tests run for minutes of simulation because of it.

## Benches and tests

`tb_iocore` loads `+CODE` and `+DATA` through the island's load port, one
word a clock, then releases the core. `tb_uart_line` is the terminal on
the far end of the UART: it decodes 8N1 at the bench's bit time and can
send bytes (`+UART_IN=`). With `+EXPECT=<file>` the bench compares every
decoded byte and prints `PASS tb_iocore` or `FAIL tb_iocore`.
`unit_tests.py iocore_cve2 iocore_hazard3` runs the phase 0 `hello`
firmware on both core options: it prints over the UART, waits on the
timer, takes one timer interrupt, and echoes two bytes from the line
model.

`tb_mpy_iobr` (`unit_tests.py mpy_iobr`) drives the bridge from a model
of `mpy_soc` on one side and a model of the I/O core on the other, at
clock ratios 1:3, 1:2, 1:1, 1.5:1, 2:1, 3:1 and six random ratios
between: random CMD, RSP, CON, CON_RX, DN, LD, EVT and UPD traffic, with
the island stopping for stretches so every FIFO fills (about 30,000
stalled hart clocks a run) and drains. Every word is checked in order,
every event and page word must arrive, and each trial ends with a
power-on reset of both sides in the middle of traffic. `tb_mpy_boot`
boots IOCB sections over SPI (code and data, code only, data only, and a
count beyond the SRAM, which must fail before any word is written).

`tb_mpy_soc` takes `+IO_CLK_NS`, `+CONSOLE`, `+IOC_LOG` (the I/O core's
debug bytes), `+GPIO_LOOP` (pad i and pad i^8 are one net; an undriven
pad reads its pull-up, else 0), and the UART line model's `+UART_OUT`,
`+UART_IN` (C escapes), `+UART_IN_US` (after boot) and `+UART_BPS`. A
board I/O run ends with `MPY_IO` lines: each output pad's changes and the
intervals between them in ms, and the bytes the line model decoded.
`hw_tests.py` compares them with a test's `.io` golden; a test's
`sim_args` and `golden_base` (one program, a golden per strap) are
manifest fields. With the `uart` strap the line model's bytes are the
program's stdout, and the bench waits for the line to go quiet after the
halt. `+UART_SCRIPT=<file>` (the manifest's `uart_script`) is a host on
the UART for the REPL tests: one step a line, `send <bytes>`, `expect
<bytes>` (wait until the line model has decoded them after the previous
match), `wait <µs>`, with `+UART_IN`'s escapes; the run ends with
`MPY_SESSION_END` (a clean exit to `hw_tests.py`) once the last step is
done and the line has been quiet for 2 ms, and a run that stops on a
step prints `MPY_SESSION_STUCK step=<n>` (`+SCRIPT_LOG` prints each
step). `+SPI_FLASH` puts an SPI NOR flash model (`tb_spi_flash`: READ,
page program, write enable, status, JEDEC id) on pads 10–13,
`+I2C_TARGET` a 24C02-style memory (`tb_i2c_target`, address 0x50, with
pull-ups) on pads 14 and 15, and `tb_adc_model` answers every
conversion with a code that depends on the channel.

The hardware suite's `io` area: `bridge_loopback` (1,000 words through
CMD and back through RSP), `bridge_regs` (EVT, EVT_SET, the state page
both ways, PING), `bridge_misaligned` and `bridge_unmapped` (the core must
halt with the unaligned and the bus fault), `mem32_align`, `pin_loop`
(every Pin method, pulls and open drain through the loopback), `blink`
(ten toggles 5 ms apart, checked at the pad), `uart_echo` (a line in and
out at 115200 8N1, checked at the pins), `sleep_accuracy` (each sleep
from 50 µs to 20 ms lasts at least as long and at most 150 µs more) and
`ticks` (`ticks_diff` and `ticks_add` across the wrap, their errors, and
the counters moving). The `console` area runs `con_print` (print, a long
line, the streams, a traceback) and `con_input` (`input()` with editing,
`sys.stdin`) on the `sim` strap and on the `uart` strap, where the bytes
are decoded at the pin. Every board I/O golden is written by hand and
names the MicroPython source it follows.

The `irq` area: `sched` (deferral, order, the full queue, an exception in
a scheduled callback), `heap_lock` (nesting, the depth, the locked
MemoryError), `pin_irq` (rising, falling, both, `flags()`, disarm,
coalesced edges), `pin_irq_hard` (a hard handler, and one that allocates:
the uncaught message, disabled), `timer_cb` (periodic, after `deinit`,
ONE_SHOT, a soft callback), `disable_irq`, `uart_irq` (RXIDLE) and
`ctrl_c` (Ctrl-C at the UART pin ends a running loop).

The `system` area: `pwm_duty` (frequency and duty at the pad, invert),
`spi_flash` (JEDEC id, page program, read back), `i2c_mem` (scan,
`writeto`'s ACK count, memory writes and reads, a missing device's
`ENODEV`), `adc`, `wdt` (fed, it keeps running; not fed, the next boot
sees `WDT_RESET`), `reset_soft` and `reset_hard` (the reset cause, and a
watchdog started before `machine.reset()` that does not fire after it).
The `console` area adds the REPL: `repl_friendly` (the banner,
expressions, a statement, continuation lines with auto-indent, an
exception, Ctrl-C in a running loop, soft reboot) and `repl_raw` (an
`mpremote` session: entering the raw REPL with a soft reset, a command in
raw-paste mode, one in plain raw mode with an exception, the namespace
kept between commands, back to the friendly REPL).

The plan's clock-ratio sweep runs the `io`, `irq` and `console` areas at
`io_clk` = hart/2 (the default, 20 ns), hart/1 (`--sim-arg
+IO_CLK_NS=10`) and hart×1.5 (`+IO_CLK_NS=6.667`); the outputs match, so
each golden holds at all three.

## Synthesis

`upycore/synth/hammer/make_hammer_design.py --top mpy_soc` builds the
class flow's design folder with the island in (the generated
SystemVerilog unit, `upycore/tools/mpy_dc_unit.py`, now takes the
island's files and CVE2's includes):

- **Two clocks.** `constraints.tcl` adds `io_clk` on `io_clk_i`
  (`--io-period`, 20 ns by default), asynchronous to `core_clk`. Every
  path between the domains ends in a two-flop synchronizer or is a
  dual-clock FIFO's memory read only after the gray-coded write pointer
  has crossed; each is bounded by `set_max_delay` to the faster clock's
  period rather than cut, so a gray pointer's bits arrive within one
  period of each other. The island's synchronous pads (the GPIO pads,
  which the pin mux routes into the SPI and I2C controllers, the ADC
  interface, UART TX, the debug byte) are timed against `io_clk`; the
  UART RX pin and the console strap, synchronized before any logic, are
  not timed.
- **SRAM macros.** The island's code and data SRAMs are the same
  `bsg_mem_1rw_sync_mask_write_bit` wrapper as the chip's, so the class
  hook swaps them for `fakeram_d4096_w32` and `fakeram_d2048_w32`
  (`vlsi.inputs.sram_parameters` lists all seven shapes).
- **Clock gate.** CVE2's behavioral clock gate (a latch and an AND) is
  `sky130_fd_sc_hd__dlclkp_1` in the generated unit
  (`iocore/rtl/asic/cve2_clock_gate.sv`), so Genus maps no latch and
  `check_syn.py`'s latch check stays clean.
- **Island timing.** In the open flow (unmapped STA, the numbers compare
  designs; they are not Genus ns) the island's worst path is 18.93 ns,
  from CVE2's instruction register through the store address into the
  UART's counters: about 53 MHz against the 50 MHz `io_clk`. Phase 4's
  blocks first pushed it to 21.8 ns through their write logic; their
  accesses now go through a register stage (Island, PWM to pin mux).

Not done here, for want of the tools: a Genus run of `mpy_soc` at 10 ns
with the island in (the plan's check for this phase), and sv2v
regeneration of `converted/mpy_soc.v` and `converted/mpy_core.v`
(`upycore/synth/hammer/README.md`).

## Measurements

`iocore/tools/io_measure.py` runs the programs in `upycore/programs/meas`
on the simulator with the bench's measurement hooks (`+MEAS_FILE`,
`+PULSE`, `+MEAS_PC`; Benches and tests) and writes
[`mpy_io_core_measurements.json`](mpy_io_core_measurements.json). Hart
at 100 MHz, io_clk at 50 MHz, the tree of commit `f313e32` (phase 6, the
phase 4 RTL); simulated time, so the numbers are exact for this RTL and
firmware, not for silicon.

| What | Result |
| --- | --- |
| `Pin.toggle()` in a `for` loop | 108,581 changes/s (9.21 µs each; 8.16–11.82 µs) |
| `Pin.value(v)`, `v` alternating | 94,379 changes/s (10.60 µs each) |
| `Pin.on()` / `Pin.off()` pairs | 128,508 changes/s (7.78 µs each) |
| Pin edge to the `Pin.irq` handler's first opcode, soft handler | min 56.4, mean 58.2, max 62.7 µs with the main program in `time.sleep_ms`; 56.1 / 58.1 / 60.1 µs while it spins in a loop |
| The same, `hard=True` | 41.2 / 43.2 / 66.6 µs sleeping; 40.9 / 42.9 / 45.0 µs spinning |
| … of which pad edge to `evt_pend` (the I/O core's part) | 5.4 / 7.3 / 9.2 µs in every case |
| Edges missed | 0 of 1,000 (one rising edge every 200 µs) |
| 1 kHz `machine.Timer` callback, period at the handler's first opcode | mean 999.990 µs, σ 1.65 µs, worst 5.18 µs off with the main program sleeping; σ 1.65 µs, worst 3.18 µs off while it spins |
| UART transmit, 4 KB in 256-byte `write()`s | 11,518 B/s at 115200 baud (100 % of the line), 99,800 B/s at 1 Mbaud (99.8 %), 292,398 B/s at 3 Mbaud (97.5 %) |
| UART receive, 2 KB back to back | all 2,048 bytes at 115200 baud; at 460800 baud 1,051 arrive, at 1 Mbaud 635 (the 256-byte ring overflows) |
| Island switching activity (SAIF), idle / busy | 0.0058 / 0.0074 toggles per bit per io_clk cycle over 117,946 bits |

Reading the table:

- **Interrupt latency is the hart's.** Of the 58 µs to a soft handler,
  7 µs is the I/O core: its polled loop seeing the GPIO latch, the event
  crossing, `evt_pend`. The rest is `_irq_dispatch` in the board I/O
  firmware (bytecode: reading `EVT`, the state page's pin counts, finding
  the handler, the schedule queue), 3,600–5,100 hart cycles. A hard
  handler skips the queue. Sleeping costs nothing extra: `_wfe` wakes on
  `evt_pend` and the dispatch runs at the loop's next jump.
- **Receive is limited by the hart, not the UART.** One `_io.uart_rx` of
  200 bytes takes 3.8 ms (about 5,700 hart cycles per three-byte answer
  word: each word is a bridge read and a firmware loop in bytecode), so the
  hart drains about 10 KB/s and the I/O core's 256-byte ring overflows
  above 115200 baud. Transmit is posted (three bytes a command word) and
  runs at line rate up to 3 Mbaud.
- **Idle is not idle.** The I/O core's firmware polls in one loop and
  never sleeps (`wfi`), so the idle island switches at 79 % of its busy
  rate. Power itself needs Genus or Joules with the SAIF files
  (`build/meas/island_{idle,active}/image.island.saif`, scoped to
  `tb_mpy_soc.u_soc.u_ioc`; `upycore/synth/hammer/README.md`, Power from
  simulated activity), which this environment does not have. Verilator's
  SAIF `DURATION` is the whole run while toggles count from
  `+SAIF_START_US`, so the per-cycle rates above are low by the boot's
  share (about half here, the same for both).

## Verification of rewrites

`iocore/tools/proofs/run.sh` proves with Yosys `sat -prove` that
`mpy_soc`'s simulator-page decode, `c_addr[31:8] == MPY_SIM_BASE[31:8]`,
equals the `mpy_region_of(c_addr) == MPY_REGION_SIM` it replaced, for
all 2^32 addresses.

## Decision D1: CVE2 or Hazard3

Both islands were built with the same peripherals and SRAMs (16 KB
code, 8 KB data) and run the same firmware. Open flow, sky130 typical
corner (`iocore/tools/island_measure.py`): area is slang, `synth
-flatten`, `dfflibmap`, ABC onto `sky130_fd_sc_hd` (no `lpflow` cells),
SRAM macros black-boxed; timing is `upycore/tools/sta/run.py`, unmapped
(the deterministic flow G3 uses; numbers compare designs and are not
Genus ns). Raw numbers: `mpy_io_core_island_phase0.json`.

| | CVE2, slow MUL | CVE2, fast MUL | Hazard3, seq MUL | Hazard3, fast MUL |
| --- | ---: | ---: | ---: | ---: |
| Core (`iocore_cpu`) area, µm² | 87,177 | 99,328 | 72,189 | 90,679 |
| Core flops | 1,415 | 1,419 | 1,201 | 1,266 |
| Island (`iocore_top`) area, µm² | 116,018 | 127,400 | 100,518 | 119,138 |
| Island flops | 2,072 | 2,076 | 1,857 | 1,922 |
| Worst path, unmapped STA, ns | 18.21 | 18.09 | 18.07 | 17.94 |
| Glue between core and island bus | none | none | AHB-Lite adapter (85 lines), +1 wait state per store | same |

The Hazard3 core includes its two AHB adapters. Read with Yosys's own
Verilog frontend and the same parameters, Hazard3 alone maps to
69,769 µm² and 1,137 flops, which agrees with slang's 72,189 µm² once the
adapters are counted (slang warns about Hazard3's static functions,
called from several always blocks; the netlists agree).

For scale, the hart's `mpy_core` worst non-FPU path in the same unmapped
flow is 15.69 ns (`timing_10ns.md`), so the island's path is 1.16 times the
hart's: if the hart closes at 10 ns, the island estimates about 11.6 ns,
86 MHz, against a 50 MHz `io_clk`.

**Chosen: CVE2 with the iterative multiplier.** Timing is the same for
both cores. Hazard3 is 15,000 µm² smaller (13 % of the island, about
0.015 mm², the area of some 600 flops), which is small next to the rest of
the island and the SoC. Integration decides it: CVE2's bus is the island's
bus (no adapter, no store wait state), and the epic branch's TinyUSB port
and firmware layout already run on it, which phase 7 reuses. The fast
multiplier costs 11,000 µm² and buys nothing the I/O firmware needs.

### Area budget (gate G5)

Phase 0 sets the budget for everything the I/O work adds to the chip,
excluding SRAM macros: the island with all its peripherals and the USB
SIE, plus the hart-side bridge and its clock-domain crossings.

| Item | Budget |
| --- | --- |
| Logic area, open flow as above (macros excluded) | ≤ 450,000 µm² |
| SRAM | ≤ 28 KB: 16 KB code, 8 KB data, ≤ 4 KB of USB endpoint buffers |

Phase 0's island is 116,018 µm² of it. The estimate for the rest: about
70,000 µm² of further peripherals (GPIO, PWM, SPI, I2C, ADC interface,
WDT, pin mux, a second UART), about 120,000 µm² for the bridge (dual-clock
FIFOs and the state page in flops), and about 60,000 µm² for the USB SIE.
