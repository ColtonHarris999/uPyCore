# The I/O core

Status: phase 0 of [`planning/rv_io_core_plan.md`](../../planning/rv_io_core_plan.md)
(the island on its own). The hart-side bridge, the boot section, the
peripherals beyond the UART and timer, and USB are added by later phases;
this page grows with them. Progress and gate results:
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
| `0x0C` | `IRQ_PEND` | Read-only, one bit per source (bit 0 UART0) |
| `0x10` | `IRQ_EN` | Sources that drive `mip.MEIP` |
| `0x14` | `SCRATCH` | Read/write |

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

## Firmware

`make -C iocore/sw APP=<dir>` builds `build/iocore/<dir>/code.hex` and
`data.hex` (one 32-bit word a line). `.vectors` and `.text` go in code
SRAM; `.rodata` and `.data` in data SRAM at their run addresses, loaded
by `mpy_boot`, so `crt0.S` copies nothing and only clears `.bss`. The
link fails past 16 KB code or 8 KB data, or past the plan's budget of
14 KB code and 7 KB data with a 1 KB stack.

## Benches

`tb_iocore` loads `+CODE` and `+DATA` through the island's load port, one
word a clock, then releases the core. `tb_uart_line` is the terminal on
the far end of the UART: it decodes 8N1 at the bench's bit time and can
send bytes (`+UART_IN=`). With `+EXPECT=<file>` the bench compares every
decoded byte and prints `PASS tb_iocore` or `FAIL tb_iocore`.
`unit_tests.py iocore_cve2 iocore_hazard3` runs the phase 0 `hello`
firmware on both core options: it prints over the UART, waits on the
timer, takes one timer interrupt, and echoes two bytes from the line
model.

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
