# Third-party notices

This repository has no project license file yet; the owners have to choose
one before publishing. The components below come from other projects and
keep their own terms.

| Component | Where | Origin | License |
| --- | --- | --- | --- |
| MicroPython v1.29.0 | `vendor/micropython` (git submodule) | <https://github.com/micropython/micropython> | MIT (`vendor/micropython/LICENSE`) |
| Ports of MicroPython semantics | `upycore/firmware/*.py`, `upycore/runtime/*.py`, `variants/upycore/*` | Behaviour and messages follow `py/*.c` of the pin; the unix variant patches its unix port | MIT (MicroPython) |
| Ports of `lib/libm` float kernels (fdlibm / musl) | `upycore/firmware/floatfmt.py` (`_lm_*`), `upycore/runtime/math.py` | `vendor/micropython/lib/libm` | fdlibm: Sun Microsystems permission notice; musl: MIT (see the headers in `lib/libm`) |
| uPy2 compiler (`mpyc`) | `vendor/upy2` (git submodule) | <https://github.com/ColtonHarris999/uPy2> | No license file in that repository yet |
| `bsg_mem_1rw_sync_mask_write_bit` interface | `upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv` | Original stand-in with the module name, parameters and ports of BaseJump STL's module, so the class flow can substitute BaseJump's file | BaseJump STL is BSD-3-Clause; no BaseJump code is copied here |
| Hazard3 comparison activity | `upycore/synth/hammer/activity/hazard3_*`, `config_benchisa.vh` | Hazard3 RISC-V core (<https://github.com/Wren6991/Hazard3>) simulation outputs and a testbench patch | Apache-2.0 (Hazard3) |

Course (EE 477) design-kit files are not part of this repository; the
Hammer scripts only refer to them by path (`upycore/synth/hammer/README.md`).
