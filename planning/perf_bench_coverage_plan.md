# perf_bench coverage plan

This is an implementation plan, not an implemented change. It covers the
MicroPython v1.29.0 `tests/perf_bench` programs that uPyCore cannot run yet,
and what each one needs before it can run. It complements
[`runtime_optimization_plan.md`](runtime_optimization_plan.md). That plan
makes AES and Fannkuch faster. This one makes the rest of the suite runnable,
so the same measurement method can cover it. The suite and its (N, M) =
(100, 100) operating point come from pivot plan §4.2.

Both plans follow the same rules. Benchmark sources stay unchanged. Each
result must match the pinned unix oracle. Firmware-first changes come before
RTL. Nothing may lengthen the clock period. No program is relabelled as
unsupported to make a table look better.

## How the status was determined

The analysis was done at `532bcb7` (benchmark branch), with the pinned
mpy-cross built from `vendor/micropython`.

- Every program was scanned for imports, builtins and methods. The results
  were compared with what the linker actually exposes: `mpy_abi.TYPES`,
  `PUBLIC_TYPES`, `NATIVES`, public firmware names, and firmware `mod_*`
  native modules.
- All 18 candidate programs, wrapped like `run-perfbench.py` at (100, 100),
  compile and link into device images with `mpy_build.build_program`. No
  compile, link, opcode or image-size failure was found. Every blocker
  below is therefore a runtime failure.
- **Not done:** no program was simulated in this pass. Verilator is not
  installed in this environment, and a source build was not permitted. The
  i686 cross compiler that the oracle needs is also missing. Rows marked
  "expected" are unconfirmed until step 0 runs.
- Pystone, AES and Fannkuch were already measured on the device
  (`timing_100mhz.md`, `runtime_optimization_progress.md`).

## Inventory

The perf_bench tree holds 27 Python files. `benchrun.py` is the harness, and
the six `viper_*` programs need the native emitter, so 20 programs remain.

| Program | Status | Blocker | Step |
| --- | --- | --- | --- |
| `misc_pystone` | Runs (measured) | none | regression only |
| `misc_aes` | Runs (measured) | none | regression only |
| `bm_fannkuch` | Runs (measured) | none | regression only |
| `core_str`, `core_qstr` | Expected to run | none found | 0 |
| `core_yield_from`, `bm_nqueens` | Expected to run | none found (generators are implemented) | 0 |
| `misc_raytrace` | Expected to run | none found (no imports; float `**` and dunder ops) | 0 |
| `bm_wordcount` | **Fails** (reported earlier, failure mode not recorded) | unknown defect; uses only `str.split`, `dict.get`, str keys | 1 |
| `core_locals` | **Fails** (reported earlier, failure mode not recorded) | unknown defect; uses only `getattr(o, n, default)` / `setattr` on an instance | 1 |
| `bm_float` | Cannot run | `from math import sin, cos, sqrt`: no `math` module | 2 |
| `bm_fft` | Cannot run | `math` (cos, log, pi) and `cmath` (pi, rect) | 2 |
| `bm_chaos` | Cannot run | `math.sqrt` and `random` (seed, randrange) | 2, 3 |
| `bm_hexiom` | Cannot run | `io.StringIO`. `print(file=)` already calls any object's `write` | 3 |
| `misc_mandel` | Cannot run | `memoryview` builtin (slice view of a bytearray, item store) | 4 |
| `core_import_mpy_single`, `core_import_mpy_multi` | Cannot run (oracle probably cannot either) | `vfs`, `io.IOBase`, `memoryview`, import from a user filesystem | 5 (defer) |
| `bm_pidigits` | Out of scope by design | needs >64-bit ints (D3); it prints SKIP on both oracle and device | none |
| `viper_*` (6) | Out of scope by design | native code emitter | none |

The standard harness (`benchrun.py`) also cannot run on the device. It
imports `time.ticks_us` and falls back to `time.perf_counter`, and the device
has no `time` module. A `time` module is excluded from this plan for now.
The step-0 runner uses the measurement builtin instead, and results are
reported in cycles.

Module facts behind the table:

- The device has only the native modules `sys`, `gc`, `micropython` and
  `builtins`, plus the frozen `array` (`upycore/runtime/array.py`). There
  are no `math`, `cmath`, `random`, `io`, `time` or `vfs` modules, and no
  firmware `mod_*` definitions.
- The oracle variant (ROM level extra features) has `math`, `cmath`,
  `random` with its extra functions, `io` and `memoryview`. Its `math` calls
  the host libm in binary32, and it seeds `random` from urandom on import.
- `memoryview` is not in `mpy_abi.TYPES`, and no firmware code handles it.

## Step 0: inventory runner and confirmation run

1. Add `upycore/tools/perf_inventory.py`. Do not extend
   `runtime_profile.py`, which the optimization work is editing. For each
   program it should:
   - wrap the program like `run-perfbench.py` at (100, 100), and also at
     (50, 25);
   - time only `run()`, using the same `bench_ticks` measurement firmware
     that `runtime_profile.py` uses;
   - prefix the harness globals and check them for collisions with each
     program's globals (the current runner admits only AES and Fannkuch
     for this reason);
   - take the expected `result()` from the oracle. Host CPython is not a
     valid reference for the float programs, because it computes in binary64.
2. Classify each run as PASS, WRONG (result differs), ERROR (exception text
   captured), TIMEOUT or SKIP. Use a 400M cycle budget so that a slow
   program is not misread as a broken one. Record cycles, GC count, image
   hashes, raw logs, and the compiler, firmware and RTL hashes, as phase 0
   of the optimization plan does.
3. Run every PASS program in all four accelerator configurations. That set
   becomes the coverage regression suite.
4. Write a JSON result file and a markdown table. They replace the
   "expected" entries in the table above.

Prerequisites: Verilator ≥ 5.032 (the Dockerfile notes that Ubuntu's 5.020
rejects the RTL), and the i686 toolchain for `make oracle`
(`Dockerfile.oracle`). Install both in the cloud environment's setup script,
or run step 0 in Docker.

Gate: any "expected" program that fails moves into step 1.

## Step 1: diagnose and fix `bm_wordcount` and `core_locals`

Both programs use only core features, so they fail because of defects, not
missing features. The earlier failure output was not kept. Reproduce each
one first with the smallest parameter set, and bisect between `+CA=0` and
`+CA=1` and between the hart and firmware paths. Check these hypotheses
first:

- **wordcount**
  - The double space in `ZEN` (`"idea  lets"`) makes `split(" ")` produce an
    empty-string key.
  - The keys are heap strings, not qstrs, and grow to about 80 entries
    through `dict.get(k, 0)` followed by a store.
- **core_locals**
  - An instance dict grows to about 25 qstr attributes through `setattr`.
  - Every miss in `getattr(obj, name, default)` raises and catches an
    `AttributeError` in firmware (`builtins.py:410`). Check that path under
    GC pressure.
- **Both:** if the earlier run used `mpy_build`'s default 50M cycle budget,
  the "failure" may have been a TIMEOUT.

For each defect, fix the root cause and add a small hardware test in the
matching area (`containers`, `objects` or `builtins`) with an oracle golden.
If the fix lands in `attrs.py` or `seqs.py`, coordinate with the optimization
work, which is changing both files.

## Step 2: `math` and `cmath` as frozen runtime modules

**Required:** `math.sqrt`, `sin`, `cos`, `log`, `pi`; `cmath.pi`, `rect`.
**Same pass, almost free:** `e`, `fabs`, `floor`, `ceil`, `isnan`, `isinf`,
`isfinite`, `tan`, `exp`. Leave the rest of the oracle's math surface for a
later pass.

Placement: add `upycore/runtime/math.py` and `cmath.py` as frozen modules,
like `array.py`. Do not put them in firmware.

- Firmware changes alter every image, including the AES, Fannkuch and
  pystone images that the optimization plan is measuring. Frozen modules
  touch only the programs that import them.
- Change `mpy_build.frozen_runtime_specs` to freeze a module only when the
  program imports it, using an AST scan like `uses_compiler`. Every other
  image then stays byte-identical. Step 0's hashes check that.
- No ABI, RTL or firmware change is needed, so nothing conflicts with the
  in-flight phases.

Accuracy:

- `sqrt` is computed correctly rounded, entirely with exact operations:
  - scale by powers of two (exact);
  - extract the 24-bit significand with `int()` (exact);
  - take an exact integer square root in int64;
  - round to nearest even and rebuild the float, again exactly.
  This matches `sqrtf` bit for bit.
- `sin`, `cos`, `tan`, `log` and `exp` are ports of the pinned
  `lib/libm` routines (`sf_sin.c`, `kf_sin.c`, `kf_cos.c`, `ef_rem_pio2.c`,
  `kf_rem_pio2.c`, and `logf`/`expf` from `math.c`). Bare-metal MicroPython
  ports use these routines. Keep their operation order, because the device
  FPU computes in binary32.
- The oracle calls glibc's `sinf`/`cosf`/`logf`, which can differ from these
  routines by one ulp. `bm_chaos` (rounded pixel percentage) and `bm_fft`
  (1e-3 tolerance) tolerate that. `bm_float` prints `%.4f`, so compare it
  with the oracle. If a last-digit difference appears, record it in
  `known_limitations.md` and do not change the benchmark.
- Port the large-argument reduction path (`kf_rem_pio2`) in full rather than
  clamping the argument.

Semantics: accept int and bool arguments, raise `TypeError` for non-numbers
and `ValueError("math domain error")` where the oracle does (`sqrt(-1)`,
`log(0)`), and handle ±0, inf, nan and subnormals. Implement `cmath.rect`
with the existing `complex` constructor.

Tests: add `modules/math_*.py` and `modules/cmath_*.py` hardware tests with
oracle goldens. Cover special values, domain errors, argument types, and a
sweep printed with `repr`, which round-trips binary32.

Cost: these functions run as bytecode and will cost thousands of cycles per
call. Measure that cost in the runner's microbenchmarks. A hardware sqrt or
range reduction is a later optimization candidate. It falls under the
optimization plan's timing rules (cycles × clock period, no long
combinational paths). This step does not do it.

## Step 3: `random` and `io`

- **`upycore/runtime/random.py`**: a bit-exact port of yasmarang from
  `extmod/modrandom.c`.
  - Functions: `seed`, `getrandbits`, `randrange` (including the
    `yasmarang_randbelow` rejection loop), `randint`, `choice`, `random`
    and `uniform`.
  - Without a seed, start from the fixed constants (`0xeda4baba`, 69, 233,
    0). The device has no entropy source, and the oracle seeds from
    urandom, so only seeded sequences can be compared.
  - Mask each operation to 32 bits. Values of 2^30 and above become boxed
    int64s. `bm_chaos` makes few calls, so that is acceptable.
- **`upycore/runtime/io.py`**:
  - `StringIO` and `BytesIO` with `write` (returns the length), `getvalue`,
    `read`, `seek`, `tell`, `close` and context-manager support.
  - An empty `IOBase`, for step 5.
  - `print(file=...)` already calls `getattr(f, 'write')` (`fmt.py:494`),
    so `bm_hexiom` needs nothing else.
- Freeze both modules on import, as in step 2.

Tests:

- seeded `random` sequences match the oracle for several seeds, including
  `randrange` bounds of 1, 2, 2^k and 2^k + 1;
- `StringIO` with `print(..., end=, file=)`;
- `bm_hexiom`'s full solution text matches the oracle.

## Step 4: `memoryview`

This is the only blocker that needs a new builtin type, so it is the only
step that changes the firmware image and the ABI.

- Append `memoryview` to `mpy_abi.TYPES` and `PUBLIC_TYPES`. Never renumber
  existing entries. Regenerate the ABI outputs with `mpy_abi.py`; do not
  hand-edit them.
- Layout: the source object, a byte offset, a length and a readonly flag
  (format `'B'` only). Store the source object, not a raw data pointer,
  and re-read its data pointer and length on every access. That keeps a
  view valid if a bytearray is reallocated, and it keeps the source alive
  for GC.
- Operations:
  - the constructor, from `bytes`, `bytearray` or `memoryview`;
  - `len` and iteration;
  - integer index get and set, with stores to a `bytes`-backed view
    raising the oracle's readonly `TypeError`;
  - step-1 slices, which return a view sharing the source. Other steps
    raise the oracle's `NotImplementedError`;
  - equal-length slice stores;
  - `bytes(mv)` and `bytearray(mv)`.
- Add one firmware helper, `_buf(x) -> (base, offset, length)`, for buffer
  consumers. Use it in bytearray slice assignment (`buf[:] = mv[a:b]`), in
  the `bytes`/`bytearray` constructors and `extend`, and later in
  `_load_mpy`.
- Dispatch: use a memoryview arm in the existing `_subscr` and
  `_setsubscr` hooks. Leave the RTL alone: the completion plan's locks
  forbid new FSM work for this. A core fast path that reuses phase 1's
  bytearray classification in `S_LSUB`/`S_SSUB` is a separate
  optimization item, to consider only if `misc_mandel` cycles justify it.
- Files: `mpy_abi.py`, `attrs.py`, `seqs.py`, `strs.py` and `builtins.py`.
  The optimization phases are editing the first three. **Start this step
  after those phases merge to main.** Treat it as an image-changing
  comparison: reproduce the baselines first, as the optimization plan
  requires.
- Tests: add `containers/memoryview_*.py` with oracle goldens. Cover
  - views of `bytes` and `bytearray`;
  - nested slices, negative and out-of-range indices;
  - readonly stores and step slices;
  - writes that become visible through the source;
  - GC when only the view is alive;
  - resizing the bytearray after creating a view;
  - all four accelerator configurations.

## Step 5 (defer, needs a decision): `core_import_mpy_*`

- **Oracle side.** The variant sets `MICROPY_READER_VFS 0` and
  `MICROPY_VFS_POSIX 0`, because posix VFS needs finalisers. As a result,
  `mp_reader_new_file` opens `/__remote/__injected.mpy` on the host
  filesystem and should fail with `OSError`. Confirm this once the oracle
  builds. A fix would mean a `unix-port.patch` change that routes the
  reader through the VFS when a path lies inside a mount.
- **Device side**:
  - a `vfs` module with `mount`/`umount` and a mount table;
  - an import path that calls `fs.stat` in `mp_import_stat` order
    (directory, `.py`, `.mpy`) for `sys.path` entries under a mount;
  - an `open` → `readinto` → `ioctl(4)` stream read;
  - a user subclass of `io.IOBase`;
  - `memoryview` (step 4);
  - `_load_mpy`, which already exists and accepts this file's 30-bit
    small-int header (it rejects only values above 31);
  - a check that `sys.modules.clear()` is harmless.
- The two programs measure import and qstr-interning cost, which pivot plan
  §4.2 places after the deadline. Recommendation: record them as SKIP with
  this reason until someone asks for full-suite coverage.

## Order and coordination

| Step | Change | Touches | Can run alongside the optimization phases? |
| --- | --- | --- | --- |
| 0 | Inventory runner and confirmation run | new tool only | Yes |
| 1 | wordcount / core_locals defects | depends on root cause | Yes, unless the fix is in `attrs.py` or `seqs.py` |
| 2 | `math`, `cmath` | new runtime modules, `mpy_build.py` freeze selection | Yes. Firmware image unchanged |
| 3 | `random`, `io` | new runtime modules | Yes. Firmware image unchanged |
| 4 | `memoryview` | ABI, `attrs.py`, `seqs.py`, firmware | **No.** Start after phases 2–4 merge |
| 5 | VFS import (deferred) | oracle patch, firmware import path | After 4 |

## Acceptance

- At (100, 100) and (50, 25), every in-scope program prints a `result()`
  that matches the pinned oracle, in all four accelerator configurations,
  and its cycles are recorded by `perf_inventory.py`.
- In-scope means everything except `bm_pidigits` and `viper_*` (SKIP by
  design), plus `core_import_mpy_*` if step 5 is deferred (SKIP with the
  oracle reason).
- The hardware suite, the project benchmark suite and the
  optimization-plan kernels show no regressions.
- Steps 0, 2 and 3 leave the AES, Fannkuch and pystone images
  byte-identical (checked by hash).
- No benchmark source is modified, and no failing program is relabelled
  as unsupported.
