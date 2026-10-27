# Vendored components

Provenance for every third-party source the coprocessor and the SoC use.
`vendor/README.md` is the index; this file is the record. Each entry has
the upstream, the pinned commit, the licence, and every local change.
A component that is not under a permissive licence is not vendored
without asking first.

## TinyUSB

| Field | Value |
| --- | --- |
| Path | `vendor/tinyusb` (git submodule) |
| Upstream | https://github.com/hathach/tinyusb |
| Commit | `b549ac1d84cbbe550c9590951e2290098b3fb16c` (2026-08-12), the commit `vendor/micropython/lib/tinyusb` pins for MicroPython v1.29.0 |
| Licence | MIT (`vendor/tinyusb/LICENSE`) |
| Used by | `coproc/sw` (device stack, CDC class) |
| Local changes | None. Configuration is `tusb_config.h` in our tree |

## no2usb

| Field | Value |
| --- | --- |
| Path | `vendor/no2usb` (git submodule) |
| Upstream | https://github.com/no2fpga/no2usb |
| Commit | `48e3f00ae3abf808285275402cb8fe486cfb76e4` (2026-03-01) |
| Licence | HDL: CERN-OHL-P-2.0 (permissive). TinyUSB driver: MIT. Its own USB stack (`fw/v0`): LGPL-3.0, **not used** |
| Used by | `coproc` USB SIE (phase 4); `coproc/sw/dcd` driver |
| Local changes | The submodule is unmodified. `coproc/sw/dcd/dcd_no2usb.c` and `dcd_no2usb_hw.h` are copies of `fw/tinyusb`, ported to the pinned TinyUSB: `dcd_init` takes the rhport init struct and returns `bool`; `dcd_edpt_xfer` takes `is_isr`; the endpoint size comes from `tu_edpt_packet_size`; `dcd_sof_enable` and `dcd_edpt_close_all` are added; `dcd_int_handler` reports bus suspend and resume from `CSR_BUS_SUSPEND`, which the upstream driver ignores. Each change is marked `upycore port` |

## CVE2

| Field | Value |
| --- | --- |
| Path | `vendor/cve2` (git submodule) |
| Upstream | https://github.com/openhwgroup/cve2 |
| Commit | `d7f21568028a1114be663599bd42145dccf28928` (2026-10-09) |
| Licence | Apache-2.0 WITH SHL-2.1, the Solderpad Hardware Licence (`vendor/cve2/LICENSE`); the lowRISC primitives it includes are Apache-2.0 |
| Used by | `coproc/rtl/coproc_top.sv`: `cve2_top` with `RV32E` = 1, `RV32M` = `RV32MFast`, no performance counters. The file list is `COPROC_RTL` in `upycore/tools/mpy_build.py` |
| Local changes | None. `boot_addr_i` is `0x80`: CVE2 resets to `boot_addr` itself and takes `mtvec` from its upper bits, so the reset entry is at `0x80` and the vector table at 0 (`coproc/sw/common/crt0.S`) |

## no2usb in the SoC

`coproc/rtl/coproc_top.sv` instantiates `usb` from `vendor/no2usb/rtl`
unmodified, with `EPDW` 32 and `EVT_DEPTH` 0 (no event FIFO, so the
no2misc FIFO it would need is not used; the driver is built without
`NO2USB_WITH_EVENT_FIFO`). The iCE40 primitives it instantiates,
`SB_RAM40_4K` and `SB_IO`, are behavioral models in `coproc/rtl/ice40_sim.sv`
that follow the primitive's bit layout. The transaction microcode ROM is
generated at build time by `vendor/no2usb/utils/microcode.py` (MIT) into
`build/coproc/fw/usb_trans_mc.hex`. `SIM` is not defined: in no2usb it
switches the transmitter off.

