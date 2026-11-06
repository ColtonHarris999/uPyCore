# perf_bench coverage progress

Results for [`perf_bench_coverage_plan.md`](perf_bench_coverage_plan.md).
Every in-scope MicroPython v1.29.0 `perf_bench` program now runs on the
device and matches the pinned unix oracle.

Measured with `upycore/tools/perf_inventory.py` at `8828b85` (benchmark
branch), Verilator 5.052, the pinned mpy-cross, and the 32-bit i686 oracle
built by `make oracle-variant`. Kernel cycles are `run()` alone, timed with
the measurement builtin `bench_ticks`, as in `runtime_profile.py`. Times use
the optimization plan's assumed 18 ns period.

## Inventory at (N, M) = (100, 100), CA and AALU on

| Program | Status | Kernel cycles | ms at 18 ns | Before this work |
| --- | --- | ---: | ---: | --- |
| `bm_chaos` | PASS | 6,935,306 | 124.8 | no `math`, `random` |
| `bm_fannkuch` | PASS | 34,381,002 | 618.9 | ran |
| `bm_fft` | PASS | 126,334,430 | 2,274.0 | no `math`, `cmath` |
| `bm_float` | PASS | 10,099,404 | 181.8 | no `math` |
| `bm_hexiom` | PASS | 59,774,955 | 1,076.0 | no `io`; `print(file=)` raised `NameError` |
| `bm_nqueens` | PASS | 152,301,477 | 2,741.4 | ran (unconfirmed before) |
| `bm_wordcount` | PASS | 22,924,681 | 412.6 | `RuntimeError: maximum recursion depth exceeded` |
| `core_locals` | PASS | 93,383,304 | 1,680.9 | `RuntimeError: maximum recursion depth exceeded` |
| `core_qstr` | PASS | 607,804 | 10.9 | ran (unconfirmed before) |
| `core_str` | PASS | 36,123,948 | 650.2 | ran (unconfirmed before) |
| `core_yield_from` | PASS | 10,028,560 | 180.5 | ran (unconfirmed before) |
| `misc_aes` | PASS | 2,344,558 | 42.2 | ran |
| `misc_mandel` | PASS | 72,558,452 | 1,306.1 | no `memoryview` |
| `misc_pystone` | PASS | 12,175,602 | 219.2 | ran |
| `misc_raytrace` | PASS | 11,018,108 | 198.3 | ran (unconfirmed before) |
| `bm_pidigits` | SKIP | | | needs >64-bit ints (D3); skips itself on the oracle too |
| `core_import_mpy_single`, `core_import_mpy_multi` | ORACLE_ERROR | | | the oracle raises `OSError: [Errno 2] ENOENT` (`MICROPY_READER_VFS 0`); deferred as plan step 5 |

The six `viper_*` programs need the native emitter and stay out of scope.

At (50, 25), the 13 programs that define a parameter set for that point pass
in all four accelerator configurations (52 runs). Raw results:
`build/perf_inventory/results.{json,md}` and
`build/perf_inventory_small/results.{json,md}`; rerun with
`python3 upycore/tools/perf_inventory.py [--points 50x25 --modes all]`.

## What changed

Frozen runtime modules (`upycore/runtime/`, plan steps 2 and 3). Each is
linked only into programs that import it, so every other image stays
byte-identical. There is no firmware, ABI or RTL change.

- `math`: the pinned `lib/libm` binary32 kernels with their operation order.
  Arguments past 2^7·π/2 are reduced exactly with 64-bit integer limbs over
  a constant table of 31-bit windows of 2/π. `sqrt` is `x ** 0.5` on the
  FPU power unit, which is accurate to about 51 bits before rounding;
  correct rounding needs 50. On the device it matched an exact integer
  square root on every input checked.
- `cmath`: `pi`, `e`, `rect`, `exp`.
- `random`: a bit-exact yasmarang port. Seeded sequences match the oracle
  over 29,400 calls.
- `io`: `StringIO`, `BytesIO` and `IOBase` over a byte buffer.
- Float literals are spelled so that the oracle's approximate parser (which
  the linker reproduces) gives the exact constants.

`memoryview` (plan step 4) is a firmware native type
(`upycore/firmware/memview.py`). It covers format `'B'` views of bytes,
bytearray and str, with the oracle's error order and messages. Subscripts
reach it through the type dict, and the RTL takes only the regenerated ABI:
one new object kind, and the exception type ids shift by one.

Defects found and fixed on the way:

- **Register-ring spill leak (RTL, plan step 1).** `spill_hp` moved down on
  every ring spill and came back only when the frame returned. A loop whose
  operand stack crossed the ring boundary on each call therefore leaked one
  16-byte-aligned chunk per iteration, until the frame hit `spill_hp`. This
  happened with a method call under three loop iterators. That was the
  wordcount/core_locals failure. The reload now frees the block that sits
  at `spill_hp`; chunks within a frame are LIFO.
  - Logic added: one flop, a register-to-register 32-bit compare (in the
    header-read state) and one 32-bit adder into `spill_hp`.
  - Verilator `--lint-only -Wall` of `mpy_soc`: 339 warnings before and
    after, with the same classes and counts per file.
- `print(file=...)` referenced undefined `sys.stdout`/`sys.stderr` objects
  and raised `NameError`.
- mpy-cross folds `math.pi` to the text `3.141592653589793`, which the
  approximate parser rounds one ulp low. The linker maps it to binary32 pi.
- `bytearray` repr lost its `b` prefix, and `str` repr escaped printable
  non-ASCII characters. Both now follow the pinned `objstr.c` /
  `objstrunicode.c`.
- `int(float)` now raises the oracle's three errors: inf, NaN, and float too
  big.

## Cost per call, and what moved out of the slow path

Measured with `bench_ticks` after subtracting a call to an empty function.

| Operation | Cycles before | Cycles after |
| --- | ---: | ---: |
| `getattr(o, name, d)`, miss on a plain instance | 33,267 | 7,274 |
| `getattr(o, name, d)`, hit | 7,573 | 3,262 |
| `math.sqrt` | 9,465 | 1,828 |
| `math.sin`, argument ≥ 2^7·π/2 | 36,282 | 19,041 |
| `math.sin`, \|x\| ≤ π/4 / medium | 3,068 / 5,579 | unchanged |
| `math.exp`, `math.log` | 7,252 / 7,520 | unchanged |
| `random.randrange` | 5,921 | unchanged |
| `memoryview` item store / bytearray store | 5,987 / 75 | unchanged |

The `getattr` miss built and caught an `AttributeError`. A plain instance
whose type defines neither the name nor `__getattr__` now answers from its
dict, as MicroPython's getattr-with-default does. That took `core_locals`
from 146.7M to 93.4M cycles; the sqrt change took `bm_float` from 13.6M to
10.1M and `bm_chaos` from 8.07M to 6.94M.

No new hardware was added for speed. Where the remaining time goes is the
optimization plan's question; candidates are:

- complex arithmetic in `bm_fft` and `misc_mandel`;
- generator expressions in `bm_nqueens`;
- `setattr` (6.4k cycles) in `core_locals`;
- a core fast path for `memoryview` stores, reusing phase 1's bytearray
  classification.

## Verification

- Hardware suite: 491 of 491 at `4729fee` (with every change except the
  last two speed commits). New tests:
  - `modules/math_funcs`, `modules/cmath_random`, `modules/io_stringio`;
  - `containers/memoryview_ops`, `strings/bytearray_repr`;
  - `control/stack_spill_loop`, the spill-leak regression.
- After the two speed commits: the math, cmath/random, and every
  `getattr`/`hasattr` hardware test pass. The `math` kernels match the
  oracle's `math` over 3,000+ arguments per function: `sqrt` bit-exact,
  the rest within 1 ulp.
- Host tests and `mpy_abi.py --check` pass.
- RTL unit benches: 25 of 26 pass. `tb_mpy_boot` times out ("boot timeout")
  the same way at `5f05007`, before any of this work, so it is a separate,
  pre-existing defect.
- Documented differences from the oracle are in
  `upycore/docs/known_limitations.md`.

## Not done

- Synthesis area/timing for the spill-reload change: Yosys is not available
  in this environment.
- Plan step 5 (VFS import) stays deferred: the oracle itself cannot run
  those programs.
- The firmware image changed, so the optimization plan's baselines must be
  reproduced again before its next comparison.
