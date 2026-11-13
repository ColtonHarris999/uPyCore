# Builtin/function tags and fixed string offset: progress

## Status — Step 0 environment verified (2026-11-13)

The host kernel has `CONFIG_IA32_EMULATION` disabled. QEMU 10.0.13
user-mode i386 now runs the pinned 32-bit MicroPython ELF with the
local i386 loader and libc. The workspace's `toolchain/env.sh` enables
a build-directory launcher at the path used by the existing Make targets,
test runner, and benchmark runners. Only the oracle runs under QEMU.
Verilator still produces RTL cycle counts, and the prescribed timing
flows run on the host with YoWASP Yosys, slang, and the Sky130 TT liberty.

| Environment check | Result |
| --- | --- |
| `make oracle` on `e12d6fe` and `tags` | Passed on both. Header `4d 06 00 1f`, four-byte pointers, binary32 floats, smoke passed, stdout and stderr separate. |
| `make oracle-mpz` | Built on both trees. |
| `python3 upycore/tools/hw_tests.py --check-goldens` | On each tree, 500 passed and zero failed. The existing manifest excludes 49 cases from oracle comparison. |
| Baseline Pi digits runner at 100×100 | Passed against pinned MicroPython MPZ. The RTL simulator reported 1,342,992 cycles. |
| Step 0 gate | Pending the remaining benchmark workloads and both timing flows. |

From the current workspace, source `toolchain/env.sh` before running the
repository commands in either checkout. The launcher is local to the
build outputs. No tracked build scripts, tests, or goldens were changed.

## Initial Step 0 blocker (2026-11-13)

The full `builtin_function_tags_plan.md` was read before changes. The
implementation branch is `tags`, starting at
`56afc3e65e726f46eb780685ad439b507a06718e` (the two planning commits above
`e12d6fe60528dcfecd7325df3a3dc690c678646e`). A separate detached worktree at
that exact baseline was used for the build. No RTL, firmware, linker,
goldens, timing constraints, clock settings, or synthesis options changed.

### Initial Step 0 work and gate

| Item | Result |
| --- | --- |
| Python | 3.12.14; requirement met |
| Verilator | 5.048; requirement met |
| YoWASP Yosys / yosys-slang | Installed tool successfully ran `help read_slang` |
| Sky130 liberty | Available; library declaration is `sky130_fd_sc_hd__tt_025C_1v80` |
| Baseline `make mpy-cross sim` | Passed after pinned vendor checkouts were populated; built `build/mpy_soc/obj/Vtb_mpy_soc` |
| Baseline `make oracle` | **Blocked:** compiled the pinned i686 MicroPython variant, but execution fails with `Exec format error` |
| Benchmark cycles | No measurements during the initial attempt |
| Timing / area | Mapped `sta/run.py` started, then interrupted after the oracle blocker was confirmed; no completed timing or area numbers claimed |
| Generic depth flow | Not run |
| Step 0 gate: numbers recorded | **NOT PASSED** |

The host lacked an i686 cross compiler and loader. Debian's GCC 14.2 i686
cross compiler, binutils, headers, and i386 libc/loader were downloaded and
extracted locally. A compiler wrapper supplied the local sysroot, dynamic
loader path, and runtime library path without modifying repository files.
Compilation and linking work. However, this execution environment refuses
both a minimal ELF32 i386 executable and the ELF32 loader itself with
`Exec format error`; the native 32-bit oracle cannot execute here.

After adding all cross-binutils to PATH, the required command reached this
failure (not a missing compiler, header, or library):

```text
variants/upycore/build.sh header
header: 4d 06 00 1f
variants/upycore/build.sh smoke
.../variants/upycore/oracle-smoke.sh: 16: .../build-upycore/micropython: Exec format error
make: *** [Makefile:116: oracle-smoke] Error 126
```

The runtime issue is resolved by the verified environment above.
Complete **all** Step 0 benchmarks and both timing flows before beginning
Step 1. The timing documentation includes mapped measurements, so mapped
timing must be included identically on both trees.

### Remaining steps

Steps 1–11 have not started. No draft PR was opened because the specified
creation point is after Step 1 passes. OBJECT-tag, firmware-tag, and string
word-2 audit tables are pending their implementation steps; there are no
completed audits or verification claims yet. All fixed design decisions
remain unchanged.

### Deviations

- A documentation-only Step 0 blocker checkpoint is committed before its
  gate passes, to preserve the investigation and the explicit blocked
  status. This is not a completed Step 0 commit and does not authorize Step 1.
- The local launcher uses QEMU user-mode emulation to execute the same
  pinned i386 oracle binary. The oracle source and both measurement
  methods are unchanged.
