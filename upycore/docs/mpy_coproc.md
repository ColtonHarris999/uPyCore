# USB coprocessor

Status: as built. The hart side (the `MBOX` source, the mailbox block in
the MMIO window, the natives) is
[`planning/interrupts_io_plan.md`](../../planning/interrupts_io_plan.md)'s;
this page owns the rest. Register rules for the hart's mailbox block are
also in [`mpy_peripherals.md`](mpy_peripherals.md) (Mailbox).

The hart runs MicroPython bytecode and has no USB stack. A small RV32EMC
core, the coprocessor, runs TinyUSB on a no2usb full-speed SIE and talks
to the hart through a mailbox and a shared SRAM. With `SYS_CONSOLE` = 2
the console (`print`, tracebacks, `input`, the REPL) is a USB CDC ACM
port.

```
                 hart clock                    |   coprocessor clock (48 MHz)
                                               |
 mpy_core ── MMIO 0x100 ── mpy_mbox ── TX fifo ─┼─▶ coproc mailbox ── CVE2 RV32EMC
                                   ◀─ RX fifo ──┼── regs 0x8000_0000    │   │
            KBD source ◀── toggle sync ◀────────┼── CMB_KBD             │   ├─ code SRAM 16 KB
                                               |                        │   └─ data SRAM  8 KB
          MMIO 0x1000 ── shared SRAM (4 KB, dual-clock) ── 0x8000_4000 ─┤
                                               |                        └─ no2usb SIE ── D+/D-
```

## Pieces

| Piece | Where |
| --- | --- |
| Coprocessor top: core, SRAMs, bus decode, mailbox regs, SIE | `coproc/rtl/coproc_top.sv` |
| Core | CVE2 (`vendor/cve2`), `RV32E` and fast `RV32M`; C is always on |
| Hart-side mailbox block | `upycore/rtl/mpy_mbox.sv` |
| Dual-clock FIFO, shared SRAM | `upycore/rtl/mpy_async_fifo.sv`, `upycore/rtl/mpy_shared_ram.sv` |
| SIE | no2usb (`vendor/no2usb/rtl`), unmodified; iCE40 primitives from `coproc/rtl/ice40_sim.sv` |
| Firmware | `coproc/sw/fw` (TinyUSB CDC, the mailbox bridge), toolchain in `coproc/sw/TOOLCHAIN.md` |
| Host model | `upycore/tb/tb_usb_host.sv` (full-speed host: NRZI, bit stuffing, CRC, SOF, control and bulk transfers) |

## Clocks and resets

The coprocessor and the SIE run on `cclk`, 48 MHz, four samples a USB
bit. The hart's clock is independent. Every signal between the domains
goes through one of: a dual-clock FIFO (gray-coded pointers, two flops),
a toggle synchronizer (the `KBD` doorbell), or the shared SRAM's two
ports. Status bits seen across the crossing (levels, `full`) are the
synchronized pointers, so they lag by up to three clocks and are always
safe: a level never reads higher than the words that are there, and
`full` never reads clear while the FIFO is full.

Power-on (`rst_n`) resets the coprocessor, its SRAMs' control, the
FIFOs, and the SIE. A system reset of the hart (`SYS_RESET`, the
watchdog) does not: the USB device stays enumerated across
`machine.soft_reset()`, as a separate USB chip would, and only the hart
side of `mpy_mbox` restarts. Bytes already in the FIFOs survive the
reset.

The code SRAM holds the firmware image from power-on: in simulation
`+COPROC=<hex>` loads it, and in a synthesis build it is the memory's
initial contents. Without an image the bench leaves `cclk` stopped and
the coprocessor never leaves reset; the hart sees an empty RX FIFO and a
TX FIFO that fills and then reports full.

## Coprocessor memory map

| Address | Size | What |
| --- | --- | --- |
| `0x0000_0000` | 16 KB | Code SRAM. Vectors at 0, reset at `0x80` (`coproc/sw/common/crt0.S`). The data port reads it (`.rodata`, the `.data` load image); stores are ignored |
| `0x0001_0000` | 8 KB | Data SRAM. `.data`, `.bss`, the stack at the top |
| `0x8000_0000` | 64 B | Mailbox registers, below |
| `0x8000_4000` | 4 KB | Shared SRAM, byte enables honored |
| `0x8001_0000` | 16 KB | no2usb core: CSR at `+0`, endpoint status and buffer descriptors at `+0x2000` (`coproc/sw/dcd/dcd_no2usb_hw.h`) |
| `0x8002_0000` | 2 KB | Endpoint RX buffer (read) |
| `0x8003_0000` | 2 KB | Endpoint TX buffer (write) |

Anything else answers the data port with an error, which the core takes
as a load or store access fault.

### Mailbox registers (coprocessor side)

| Offset | Name | Rule |
| --- | --- | --- |
| `0x00` | `CMB_TX` | A store pushes the word towards the hart. Dropped when full, and sets overrun |
| `0x04` | `CMB_RX` | A load pops the word from the hart; 0 when empty |
| `0x08` | `CMB_STATUS` | Bits 4:0 RX level, bits 12:8 TX level, bit 16 TX full, bit 17 RX not empty, bit 18 TX overrun (write 1 to clear) |
| `0x0C` | `CMB_KBD` | Any store rings the hart's `KBD` source (Ctrl-C) |
| `0x10` | `CMB_IRQEN` | Bit 0: RX not empty drives `irq_fast[0]`. Bit 1: the SIE's IRQ drives `irq_fast[1]` |
| `0x14` | `CMB_CYCLES` | Read-only, a free-running count of `cclk` |
| `0x18` | `CMB_DEBUG` | A store's low byte goes to the simulation's coprocessor log (`+COPROC_LOG`); nothing in hardware |

The firmware polls; it leaves `CMB_IRQEN` at 0.

## Hart side

The mailbox block is at MMIO offset `0x100` (`mpy_peripherals.md`,
Mailbox). The FIFOs are 16 words each way. The shared SRAM is the
second 4 KB of the MMIO window, `0x4000_1000`–`0x4000_1FFF`: word access
only, as for every MMIO address, and untagged. It is not in the GC pool
and not in either root span, so a value stored there is never a root and
never moves: the collector does not scan it.

`MBOX` (source 7) sets each time a word reaches the hart's RX FIFO; it
wakes `machine.idle` like any source event.

Natives (append-only ids in `upycore/tools/mpy_abi.py`):

| Native | Effect |
| --- | --- |
| `_mbox_send(w)` | Push `w` (an int, its low 32 bits) if the TX FIFO has room; `True`, else `False` |
| `_mbox_recv()` | Pop a word as an int, or `None` when the RX FIFO is empty |
| `_mbox_avail()` | The RX level |

`machine.Mailbox()` wraps them: `send(w)`, `recv()`, `any()`, and
`Mailbox.SHARED` (`0x4000_1000`) for `machine.mem32`.

## Messages

A word is a channel in bits 31:24 and a payload in bits 23:0.

| Channel | Direction | Payload |
| --- | --- | --- |
| `0x00` `CON` | both | One console byte in bits 7:0 |
| `0x01` `CTRL` | hart → coproc | Bits 23:16 the command. `0x01` `KBD`: bit 8 armed, bits 7:0 the interrupt character. `0x02` `KBD_TEST`: ring `CMB_KBD` once, about 1000 cycles later |
| `0x01` `CTRL` | coproc → hart | Bits 23:16 `0x80` `STATE`: bit 0 configured, bit 1 suspended, bit 2 DTR |
| `0x02` `ECHO` | both | The coprocessor sends the word back unchanged |
| `0x03` `COPY` | both | Bits 9:0 a source and bits 19:10 a destination word index in the shared SRAM. The coprocessor copies the word and answers with the same message |

Console bytes from the hart are written to the CDC IN endpoint while a
host has configured the device; otherwise they are dropped, so a program
never blocks on an absent host. Bytes from the CDC OUT endpoint become
`CON` words, except the armed interrupt character, which rings
`CMB_KBD` instead. `_boot` arms Ctrl-C on the USB console the way it
does on the UART, and `micropython.kbd_intr` sends `KBD`.

## Firmware

`coproc/sw/fw/main.c` is one loop: service the SIE (`tud_int_handler`,
`tud_task`), drain the hart's words, move CDC OUT bytes to the hart while
the TX FIFO has room, flush CDC IN. TinyUSB is configured for one CDC ACM
interface (`coproc/sw/fw/tusb_config.h`, `usb_descriptors.c`); VID:PID
`1209:5550`, the pid.codes test range. Suspend and resume are reported
with `STATE`.

The build (`make -C coproc/sw/fw`) writes `build/coproc/fw/coproc.hex`,
one 32-bit word a line for `$readmemh`, and checks the sizes against the
16 KB and 8 KB SRAMs at link time.
