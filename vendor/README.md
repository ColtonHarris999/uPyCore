# Vendored third-party sources

| Path | Upstream | Role |
| --- | --- | --- |
| `micropython/` | [micropython/micropython](https://github.com/micropython/micropython) tag **v1.29.0** (`0fd6c573`) | Pinned bytecode, `mpy-cross`, `tools/mpy-tool.py`, and the unix oracle. The flash-image tool reads this tree; the RTL does not. The variant lives in this repo at `variants/upycore`, not in the submodule. |
| `tinyusb/` | [hathach/tinyusb](https://github.com/hathach/tinyusb) `b549ac1d`, the commit MicroPython v1.29.0 pins | USB device stack for the coprocessor firmware (`coproc/sw`). MIT |
| `no2usb/` | [no2fpga/no2usb](https://github.com/no2fpga/no2usb) `48e3f00a` | Full-speed USB SIE for the coprocessor, and the source of the TinyUSB driver in `coproc/sw/dcd`. HDL CERN-OHL-P-2.0, driver MIT |
| `cve2/` | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) `d7f21568` | The coprocessor's RV32EMC core (CV32E20), built `RV32E` with fast `RV32M`. Apache-2.0 WITH SHL-2.1 (Solderpad) |

`make oracle-header` builds `mpy-cross` from that tag and prints `header: 4d 06 00 1f` for a bytecode-only compile (`-msmall-int-bits=31`, no `-march`, `-O0`). `make oracle` also builds the 32-bit unix variant and runs `variants/upycore/smoke.py`. `Dockerfile.oracle` builds both into one image. The submodule checkout is not patched; `variants/upycore/unix-port.patch` is applied to the build tree.

Licence: MicroPython is MIT. This tree vendors it unmodified.

Clone with the pin:

```bash
git clone --recurse-submodules <this-repo>
# or, after a plain clone:
git submodule update --init --recursive
```

`VENDORED.md` records the provenance and every local change for the
coprocessor components.
