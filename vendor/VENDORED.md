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
| Local changes | The submodule is unmodified. `coproc/sw/dcd/dcd_no2usb.c` and `dcd_no2usb_hw.h` are copies of `fw/tinyusb`, ported to the pinned TinyUSB: `dcd_init` takes the rhport init struct and returns `bool`; `dcd_edpt_xfer` takes `is_isr`; the endpoint size comes from `tu_edpt_packet_size`; `dcd_sof_enable` and `dcd_edpt_close_all` are added. Each change is marked `upycore port` |
