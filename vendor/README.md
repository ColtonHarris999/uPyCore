# Vendored third-party sources

| Path | Upstream | Role |
| --- | --- | --- |
| `micropython/` | [micropython/micropython](https://github.com/micropython/micropython) tag **v1.29.0** (`0fd6c573`) | Pinned bytecode, `mpy-cross`, `tools/mpy-tool.py`, and the unix oracle. The flash-image tool reads this tree; the RTL does not. The variant lives in this repo at `variants/upycore`, not in the submodule. |
| `cve2/` | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) `d7f21568` | The I/O core (RV32EMC, `RV32MSlow`), unmodified (`iocore/rtl/iocore_cpu.sv`). Apache-2.0 WITH SHL-2.1 |
| `hazard3/` | [Wren6991/Hazard3](https://github.com/Wren6991/Hazard3) `8af99293` (v1.1.1) | The I/O core's other option, measured for decision D1, and the hart's benchmark baseline. Apache-2.0 |
| `no2usb/` | [no2fpga/no2usb](https://github.com/no2fpga/no2usb) `48e3f00a` | The I/O core's full-speed USB SIE (`iocore/rtl/usb/iocore_usb.sv`), unmodified; its iCE40 primitives are `iocore/rtl/usb/ice40_cells.sv`, its microcode ROM `usb_trans_mc.svh` (from `utils/microcode.py`, `iocore/tools/gen_usb_mc.py`). Its TinyUSB driver, ported, is `iocore/sw/usb/dcd_no2usb.c`. HDL CERN-OHL-P-2.0, driver and microcode tool MIT; its own USB stack (`fw/v0`, LGPL-3.0) is not used |
| `tinyusb/` | [hathach/tinyusb](https://github.com/hathach/tinyusb) `b549ac1d`, the commit MicroPython v1.29.0's `lib/tinyusb` pins | The I/O core firmware's USB device stack (CDC ACM), unmodified; configuration in `iocore/sw/usb/tusb_config.h`. MIT |

`make oracle-header` builds `mpy-cross` from that tag and prints `header: 4d 06 00 1f` for a bytecode-only compile (`-msmall-int-bits=31`, no `-march`, `-O0`). `make oracle` also builds the 32-bit unix variant and runs `variants/upycore/smoke.py`. `Dockerfile.oracle` builds both into one image. The submodule checkout is not patched; `variants/upycore/unix-port.patch` is applied to the build tree.

Licence: MicroPython is MIT. This tree vendors it unmodified.

Clone with the pin:

```bash
git clone --recurse-submodules <this-repo>
# or, after a plain clone:
git submodule update --init --recursive
```
