# The I/O core

Status: phases 0 to 2 of [`planning/rv_io_core_plan.md`](../../planning/rv_io_core_plan.md)
(the island, the hart-side bridge, the boot section, polled board I/O and
the UART console). Events on the hart, the remaining peripherals, the
REPL and USB are added by later phases; this page grows with them. Progress and gate results:
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
| `0x800`–`0x87C` | State page, I/O core words | 32 words the I/O core writes and the hart reads (stores are ignored) |
| `0xC00`–`0xC1C` | State page, hart words | 8 words the hart writes (and reads back) and the I/O core reads |

Each I/O core page word arrives through UPD as a whole word, so a load
never sees half of one; a word updated twice in a row may skip the first
value. `evt_pend` is the flop `|(EVT & EVT_EN) && !EVT_MASK[0]`, the only
signal the I/O work gives `mpy_core` (from phase 3).

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
| `0x01` | `SYS` | bits 23:16 op: `0x01` PING, `0x02` FREQ | PING: the protocol version (2); FREQ: io_clk in Hz |
| `0x02` | `ECHO` | anything | the same word |
| `0x03` | `EVT` | bits 15:0 | raises those events (a bridge test) |
| `0x04` | `PAGE` | bits 4:0 a page word; the next CMD word is its value | the CMD word, after the page word is pushed (a bridge test) |
| `0x05` | `DNRD` | bits 2:0 a hart word | that word as the I/O core sees it |
| `0x10` | `PIN_INIT` | bits 4:0 pin, 7:5 mode (0 IN, 1 OUT, 2 OPEN_DRAIN), 9:8 pull (0 none, 1 up, 2 down), bit 10 set the value, bit 11 the value | — |
| `0x11` | `PIN_WRITE` | bits 4:0 pin, bit 8 the value | — |
| `0x12` | `PIN_TOGGLE` | bits 4:0 pin | — |
| `0x20` | `UART_INIT` | bits 3:0 id; the next word is the baud rate | the rate the divider gives |
| `0x21`–`0x23` | `UART_TX1`–`TX3` | one to three bytes, the first in bits 7:0 | — |
| `0x28` | `UART_RX` | bits 7:0 the most bytes wanted | the count k, then ceil(k/3) words of three bytes |
| `0x29` | `UART_DEINIT` | | — |
| `0x30` | `TIMER_INIT` | bits 1:0 id, bit 2 periodic; the next word is the period in µs | — |
| `0x31` | `TIMER_DEINIT` | bits 1:0 id | — |

An open-drain pin drives its pad only while its output is 0: `PIN_INIT`,
`PIN_WRITE` and `PIN_TOGGLE` keep its `OE` bit the inverse of its `OUT`
bit.

### State page

Words the I/O core writes (`0x800 + 4*i` in the hart's window):

| Word | Name | Contents |
| --- | --- | --- |
| 0 | `VERSION` | `0x494F_0002`: protocol version 2 |
| 1 | `PIN_IN` | The pin levels (`GPIO IN`), pushed when they change |
| 3 | `MS` | The island timer's millisecond count (mpy_iobr's tick crossing, not UPD) |
| 4 | `US` | Its microsecond count (the same) |
| 5 | `CYCLES` | io_clk cycles, pushed each millisecond |
| 6 | `UART0` | Bits 15:0 bytes waiting in the RX ring, 27:16 room in the TX ring, bit 31 TX busy (queued or on the wire) |
| 7 | `SEQ` | CMD words the I/O core has finished |
| 8–11 | `TIMER0`–`3` | Expirations of each software timer |

`SEQ` orders commands against state-page reads: `machine` counts the CMD
words it sends, and before a read whose answer depends on earlier
commands (`Pin.value()`, `UART.any()`, `txdone()`) it waits until `SEQ`
has caught up (`_fence`). A read with nothing in flight costs one more
word load.

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
1.9 KB of code.

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
| `Timer(id, *, mode, freq, period, callback)`, `init`, `deinit` | `TIMER_*` commands; ids 0–3. Callbacks come with phase 3; the expirations are counted in the page |
| `mem32` | The bridge window (above) |
| `freq()` | The hart's clock, 100 MHz (a constant) |
| `idle()` | Returns at once (phase 3 waits for an event) |
| `time.ticks_ms`, `ticks_us`, `ticks_cpu`, `ticks_add`, `ticks_diff` | `MS` and `US` from the page, `ticks_cpu` the hart's cycle counter (`_io.cpu()`); period 2^30, `extmod/modtime.c`'s arithmetic and `OverflowError` |
| `time.sleep`, `sleep_ms`, `sleep_us` | Poll `US` until the time has passed, so a sleep is never shorter than asked (phase 3 idles instead) |
| `time.time`, `time_ns` | Seconds and nanoseconds since the I/O core started (there is no RTC) |

`machine.Pin`, `UART` and `Timer` raise `OSError(ENODEV)` (19) when the
I/O core is not running (`IOC_CTRL` bit 0 clear).

## Console

The strap `console_sel_i` (`+CONSOLE=sim|uart|usb` on the bench) picks
the console. Output: the firmware writes console bytes as always (`_wr`
and `_we`, posted stores to `SIM_STDOUT` and `SIM_STDERR`), so the hart
spends the same cycles in every mode. With the `uart` strap `mpy_soc`
sends those bytes into the bridge's CON FIFO instead of to the `con_*`
port, and the I/O core moves them into UART0's TX ring; when CON is full
the next store waits, as `print` waits on a slow UART. stdout and stderr
share the UART, in order. Output is not cooked (`\n` is sent as is).

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
`input()` raises `EOFError` as at the end of a stream. The REPL is
phase 4.

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
halt.

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

The plan's clock-ratio sweep runs the `io` and `console` areas at
`io_clk` = hart/2 (the default, 20 ns), hart/1 (`--sim-arg
+IO_CLK_NS=10`) and hart×1.5 (`+IO_CLK_NS=6.667`); the outputs match, so
each golden holds at all three.

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
