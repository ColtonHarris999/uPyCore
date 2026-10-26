# Coprocessor toolchain (RV32EMC, ilp32e)

Status: Phase 0 spike, done. RV32E is practical with stock packages;
the fallback to RV32IMC is not needed.

The USB coprocessor is an RV32EMC core (`upycore/docs/mpy_coproc.md`).
Its firmware is C with TinyUSB, built with GCC and picolibc for
`-march=rv32emc_zicsr -mabi=ilp32e`.

## Recipe

Ubuntu 24.04 (the CI image family) packages everything:

```bash
apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
                picolibc-riscv64-unknown-elf
```

| Package | Version tested |
| --- | --- |
| `gcc-riscv64-unknown-elf` | 13.2.0-11ubuntu1+12 |
| `binutils-riscv64-unknown-elf` | 2.42-1ubuntu1+6 |
| `picolibc-riscv64-unknown-elf` | 1.8.6-2 |

The GCC multilib list already has `ilp32e` libraries:
`rv32e`, `rv32ea`, `rv32em`, `rv32eac`, and `rv32emac`
(`riscv64-unknown-elf-gcc -print-multi-lib`). There is no `rv32emc`
entry. `-march=rv32emc_zicsr -mabi=ilp32e` selects `rv32em/ilp32e`
(`-print-multi-directory`), so libgcc and picolibc are linked without
compressed instructions. That is correct code: the C extension does not
change the ABI. It costs a few hundred bytes, because the firmware calls
little of the C library (`memcpy`, `memset`).

Compile and link flags:

```make
ARCH    := -march=rv32emc_zicsr -mabi=ilp32e
CFLAGS  := $(ARCH) -Os -ffunction-sections -fdata-sections --specs=picolibc.specs
LDFLAGS := $(ARCH) --specs=picolibc.specs -nostartfiles -T coproc/sw/common/coproc.ld \
           -Wl,--gc-sections
```

`coproc/sw/common/crt0.S` is the reset entry and vector table.
`coproc/sw/common/coproc.ld` places code at `0x0000_0000` and data at
`0x0001_0000`. `CODE_SIZE` and `DATA_SIZE` are linker symbols; a build
that does not fit fails at link time.

Building a compressed `rv32emc/ilp32e` picolibc is possible (picolibc's
meson cross files take `-march`), but it is not needed for the sizes
below. If it is ever needed, record the meson invocation here.

## Spike

```bash
make -C coproc/sw/spike
```

builds four images and prints the table. Each one links TinyUSB's device
stack (`vendor/tinyusb`, pinned at the commit MicroPython v1.29.0 uses)
with a CDC echo loop (`coproc/sw/spike/main.c`).

- `cdc`, `cdc_hid`, `cdc_dfu` use `dcd_stub.c`, a DCD whose entry points
  do nothing. They measure the stack and the class drivers.
- `cdc_no2usb` links the real driver, `coproc/sw/dcd/dcd_no2usb.c`.

Stack figures come from `-fcallgraph-info=su`
(`coproc/sw/tools/spike_report.py`): the deepest acyclic path from
`main` and from `dcd_int_handler`, plus a 64-byte trap frame for the
interrupt path. TinyUSB's class-driver table is reached by function
pointer; the script resolves every indirect call to every class-driver
entry and `tud_*_cb` callback, which over-approximates the real targets.

### Results

`-Os`, GCC 13.2, bytes:

| Image | text | data | bss | stack (main) | stack (IRQ) | RAM total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CDC, stub DCD | 6614 | 24 | 760 | 232 | 204 | 1220 |
| CDC + HID keyboard, stub DCD | 7970 | 24 | 796 | 232 | 204 | 1256 |
| CDC + DFU runtime, stub DCD | 6978 | 24 | 760 | 232 | 204 | 1220 |
| CDC, no2usb DCD | 8850 | 24 | 1404 | 360 | 244 | 2032 |
| CDC, no2usb DCD, RV32IMC (`ilp32`) | 8880 | 24 | 1404 | 448 | 336 | 2212 |

RV32E text is within 0.3% of RV32I. The 16-register file mostly shows up
in the stack: fewer callee-saved registers to spill.

The production firmware adds the mailbox bridge, `KBD` and `CTRL`
handling, and the suspend path. Those are estimated at 1.5–2.5 KB of
text and under 1 KB of data. `machine.USBDevice` adds the runtime
descriptor builder and the `USBDEV` channel (TinyUSB's own runtime class
support plus about 2 KB). DFU (the full DFU class, not the runtime stub)
adds about 3 KB, and the flash write path depends on the flash interface.

### Recommendation

| Configuration | Code SRAM | Data SRAM |
| --- | ---: | ---: |
| CDC REPL bridge (phases 3–4) | **16 KB** | **8 KB** |
| + `machine.USBDevice` + DFU (phase 5) | 32 KB | 8 KB |

Both fit the planning figure. The phase 5 total (40 KB) is below the
64 KB line that would need a decision. The data SRAM is mostly headroom
at 8 KB: TinyUSB's state is 1.4 KB and the worst stack is 0.6 KB.

## SIE and DCD

Upstream TinyUSB has one driver for an open-source full-speed SIE,
`portable/valentyusb/eptri` (ValentyUSB `eptri`). The candidates:

| SIE | HDL / licence | TinyUSB DCD | Buffers | Status |
| --- | --- | --- | --- | --- |
| ValentyUSB `eptri` | Migen (Python), BSD-3-Clause | In TinyUSB (`portable/valentyusb/eptri`) | One shared FIFO per direction, not per endpoint | Last commit 2022. Needs Migen and LiteX to produce Verilog, and a LiteX `csr.h` |
| **no2usb** (`no2fpga/no2usb`) | Verilog, CERN-OHL-P-2.0 (permissive); its TinyUSB driver is MIT | In the core's repo (`fw/tinyusb/dcd_no2usb.c`), not in TinyUSB | Buffer descriptors per endpoint, dual-BD ping-pong, 16 endpoints | Core maintained (last commit 2026-03). The driver predates TinyUSB's current DCD API |
| `ulixxe/usb_cdc` | Verilog, MIT | None; CDC is in hardware | Fixed CDC function, no CPU interface | Not an SIE for a stack |
| OpenCores `usb1_funct` | Verilog, BSD-style | None | Shared buffer memory | Unmaintained |

**Chosen: no2usb.** It meets the SIE requirements in the prompt
(NRZI, bit stuffing, CRC5/CRC16, automatic handshakes, per-endpoint
buffer descriptors with ping-pong) and it is the only candidate with an
existing TinyUSB driver and per-endpoint buffers. The driver needed four
API changes for the pinned TinyUSB: `dcd_init` takes the rhport init
struct and returns `bool`, `dcd_edpt_xfer` takes `is_isr`, the endpoint
size comes from `tu_edpt_packet_size`, and `dcd_sof_enable` and
`dcd_edpt_close_all` are new entry points. The port is
`coproc/sw/dcd/dcd_no2usb.c`; the changes are marked in the file.

The HDL targets iCE40. Three `SB_RAM40_4K` instances (endpoint buffers,
endpoint status, microcode ROM) and the `SB_IO` pad buffers are
iCE40 primitives. Phase 4 supplies behavioral equivalents and a pad
model in our tree and leaves the vendored files unmodified where it can;
`vendor/VENDORED.md` records every change.

CERN-OHL-P-2.0 is a permissive licence but is not one of the four the
prompt names (Apache-2.0, MIT, BSD, Solderpad). It is recorded as an
open question in the Phase 0 report.
