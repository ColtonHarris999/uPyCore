# Publish-readiness review

A full review of the design, the firmware, the tools, the tests and the docs,
started at `benchmark` @ `aca1b5e` and **re-verified at `f15327a`**
(2026-11-07), after the ongoing runtime and timing work landed 47 commits.
Nothing in `upycore/` was edited. Benchmark and timing work is still in
progress on the same files, so this report lists what has to change, and
how, for agents to implement after that work.

Every item has an ID, a priority, an effort, the files, the evidence, the
change, and how to check it. **Line numbers are as of `f15327a`. Re-find
each anchor by the quoted code before you edit.**

- **Priority.** **P0** blocks publishing (wrong results, a red suite, legal,
  a broken reference). **P1** is a large or cheap win. **P2** is worth
  doing. **P3** is polish.
- **Effort.** **S** is under a day, **M** is a few days, **L** is a week or
  more.
- **Measured** numbers come from runs in this review (§2). **Estimated**
  numbers are labeled as estimates.

Already fixed by the ongoing work, and not repeated below:
- the GC allocation table moved from 61K flops to a 600×64 SRAM (`bd8cf62`);
- the `mpy_mem` bank select no longer waits for the image-offset add
  (`8c0eecf`);
- the fetch → decode → `jt` path is registered (`4f492bb`);
- `math`, `cmath`, `random` and `io` exist as frozen runtime modules
  (`979af61`);
- the `converted/*.v` netlists were regenerated (`612df65`).

## Implementation status (2026-11-08)

The items below were implemented after the review. Measurements:
`perf_inventory.py` (MicroPython `perf_bench`, `run()` cycles) and pystone
(`timing_bench.py` source, 300 loops), on the same toolchain, before
(`7f837a2`) and after.

| Workload | Before (`7f837a2`) | After | Change |
| --- | ---: | ---: | ---: |
| pystone (300 loops) | 12,118,317 | 11,376,711 | −6.12% |
| bm_chaos | 6,948,057 | 6,514,714 | −6.24% |
| bm_fannkuch | 1,557,883 | 1,222,304 | −21.54% |
| bm_fft | 126,511,032 | 114,006,070 | −9.88% |
| bm_float | 10,116,886 | 8,888,688 | −12.14% |
| bm_hexiom | 57,598,499 | 52,958,870 | −8.06% |
| bm_nqueens | 115,923,106 | 105,167,968 | −9.28% |
| bm_wordcount | 22,934,138 | 21,906,937 | −4.48% |
| core_locals | 93,410,486 | 84,450,064 | −9.59% |
| core_qstr | 607,828 | 556,980 | −8.37% |
| core_str | 36,138,426 | 33,169,284 | −8.22% |
| core_yield_from | 10,028,620 | 9,997,283 | −0.31% |
| misc_aes | 2,344,808 | 2,185,698 | −6.79% |
| misc_mandel | 72,749,009 | 59,834,828 | −17.75% |
| misc_pystone | 12,183,290 | 11,441,678 | −6.09% |
| misc_raytrace | 11,031,168 | 10,203,308 | −7.50% |
| int/float arithmetic loops (`timing_bench.py`) | | | −9.5% to −21.4% |

Every result matches the oracle and the baseline. The hardware suite passes
500 of 500 (mpy-cross), and the 28 RTL benches pass.

| Item | Status |
| --- | --- |
| A1 `abs(complex)` | Done: `_fsqrt` uses the FPU's correctly rounded `** 0.5` |
| A2 complex `**` | Done: `objcomplex.c` order with ported `lib/libm` kernels (`_lm_*`, new `atanf`/`atan2f`); within a few ulp of the oracle |
| A3 complex `/` | Done: `objcomplex.c` order |
| A4 `abs()` | Done: sign-bit float abs, bools as ints, and **B7** a core native (`ABI_N_ABS`, `ALU_ABS`) with `_abs_fb` for everything else |
| A5 `round()` | Done: `mp_builtin_round` semantics |
| A6 binary32 folding in `mpy-cross` | **Deferred**: a binary32 `mpy-cross` breaks uPy2's byte-exact contract with `mpy-cross`; needs a matching uPy2 change. Documented in `known_limitations.md` |
| A7 SSE oracle | Done (`mpconfigvariant.mk`); no golden changed |
| B1 posted stores, burst loads | Done: a store posts once granted (`m_gnt_i`; `wpend` counts its ack, a 4-entry FIFO keeps addresses for a fault halt); bursts read the frame header and stack on a fill, the function object, the raw-code header and the module bases on a call; the locals clear is one store per cycle. Simulator-page accesses drain first (`S_MDRAIN`). No drain is needed before GC or accelerator commands: the SRAM and the map cache take a store at its grant |
| B3 skip `S_FETCH` | Done (`go_next()` for 14 fall-through sites; `S_DEC` re-checks spill/reload/fault) |
| B4 numeric fast path | Done (`S_BIN`/`S_UN` → `S_NUM_GO` for unboxed operands) |
| B5 image wait state 0 | Done |
| B11 GC zeroing | Done: one zero store per grant (`mem_gnt_i`) |
| B12 short-list streaming | Done: reads and writes issue on every grant |
| C1 GC table in SRAM | Done earlier by `bd8cf62` |
| C3 dead complex FPU logic | Done: `upycore_fpu` is a 64-bit scalar unit |
| C4 dead RTL | `mpy_container` removed; `mpy_periph`/`mpy_irq` marked not integrated; `mpy_regfile` and `mpy_prelude_decode` kept for their benches |
| D2 scoreboard bounds | Done: range ends, aligned bases and valid bits registered at push (collection and short-list) |
| D3 reset | Done: 2-flop synchronizer; boot, GC and core resets are flop outputs. The two remaining `SYNCASYNCNET` lint warnings are those flops also read as data, which is intended |
| E1 tests | Done: `alu/complex_abs`, `complex_div`, `complex_pow`, `abs_edge`, `round_edge`, `containers/wide_display` |
| E3 golden check | Done: addresses compared masked |
| E4 CI | Partly: `goldens` job, profile protocol test and phase-1 check in `make test-host`; no lint job yet |
| E5 `TESTING.md` | Done |
| E7 suite | `compiler_suite` compares float spellings by device binary32 (also inside const tuples); `shortlist_methods` no longer asserts a bool-index insert; `star_wide_oom` fills deterministically and binds its globals before measuring |
| F2–F5 docs | Done: README, `NOTICE.md`, `planning/` archived, `known_limitations.md`, stale doc passages |
| F1 license | **Open**: the owners must choose a project license (`NOTICE.md` lists third-party terms) |
| Not started | B2 (the locals clear is one store per cycle; the range is not narrowed), B6, B8, B9, B10, C2, C5, D1, D4, D5, E2, E6, F6 |

Found and fixed while implementing: `BUILD_LIST`, `BUILD_TUPLE` and
`BUILD_SET` with 256 or more items lost elements (8-bit counters), and the
spill-chain walk gave up after 64 chunks, so a display of about 500 or
more items read `NULL`s.

---

## 1. Summary

The design is close. The ongoing work cut both profiled kernels by about
96% (AES 59.6M → 2.29M cycles, Fannkuch 44.2M → 1.56M), and estimates the
period at about 10.5 ns, against 18 ns at the last post-route run. All 29 RTL
unit benches and the host unit tests pass.

It is not yet publishable:

1. **The acceptance suite is not green under its own rules.**
   - `containers/shortlist_methods` has a hand-written golden that the
     oracle does not produce, so `--check-goldens` fails.
   - `generators/gen_repr`'s golden check is flaky.
   - `compiler_suite.py` fails on `math_funcs.py`, so `make test-host`
     and CI's host job are red.
   - `timing_10ns.md` records `calls/star_wide_oom` failing. It passed in
     this review, so that needs reconciling.

   (E7, E3)
2. **The firmware computes wrong numeric results that the suite does not
   test.** Every case below still reproduces at `f15327a`. (§A)
   - `abs(complex)` is wrong outside about 2e-3 ≤ |z| ≤ 5e2.
   - Complex `**` is wrong for essentially every input.
   - Complex division does not follow `objcomplex.c`.
   - `abs(-0.0)`, `abs(True)`, and `round()` of large ints or with an int
     `ndigits` are wrong.
   - Float constants folded by the host `mpy-cross` differ from the
     oracle: `1/3 == 1.0/3.0` is `False` on the device.
3. **The hardware complex path is dead, and complex math is slow.**
   `mpy_alu` ties the FPU's `complex_i` to 0, so complex arithmetic runs
   in firmware: about 5,500 cycles per complex add, 4,400 per
   `abs(complex)` and 21,500 per `z**2`. The FPU's complex sequences follow
   CPython semantics, not MicroPython's, so they cannot simply be wired
   up. (A1, B6, C3)
4. **Performance is bound by single-outstanding memory round trips.** At
   `f15327a`:
   - `S_MWAIT` is 46% of AES cycles and 26% of Fannkuch cycles;
   - call-frame service is 20% of AES;
   - waiting for the allocator is 17.5% of Fannkuch, because `mpy_gc`
     zeroes one word per round trip;
   - waiting for the short-list engine is 12% of Fannkuch, because it also
     moves one word per round trip.

   (B1, B2, B11, B12)
5. **The largest logic block is a binary64 FPU for binary32 floats.** About
   70% of the ALU's 88K generic cells. (C2, C3)
6. **Publishing hygiene:**
   - There is no LICENSE.
   - The README contradicts itself.
   - `planning/` describes a tree that no longer exists.
   - The oracle is built with x87 math, so it is not a strict binary32
     reference.
   - Resets are driven through logic.

   (F*, A7, D3)

### Top items by value

| ID | Item | Pri | Effort | Measured / expected effect |
| --- | --- | --- | --- | --- |
| E7 | `compiler_suite` fails on `math_funcs.py`; `shortlist_methods` golden is not oracle output; reconcile `star_wide_oom` | P0 | S | `make test-host` and `--check-goldens` fail at `f15327a` |
| A1 | `abs(complex)`: use the hardware sqrt | P0 | S | Today `abs(1e10+0j)` = 1.22e16. **Fix validated bit-exact** against the SSE oracle on 11 cases |
| A2 | Complex `**` and negative-base fractional `**` | P0 | M | Today `(1+2j)**2` = 18052-2817j |
| A3 | Complex `/` in `objcomplex.c` order | P0 | S | **Fix validated bit-exact** on 5 cases |
| A4/A5 | `abs()` and `round()` edge cases | P0 | S | `abs(-0.0)` = -0.0, `abs(True)` = True, `round(16777217)` = 16777216 |
| A6 | Build `mpy-cross` with binary32 floats | P0 | S | `1/3 == 1.0/3.0` is `False` today |
| A7 | Build the oracle with SSE math | P0 | S | **0 of 478** goldens change; removes x87 artifacts |
| F1 | Add a LICENSE and third-party notices | P0 | S | Legal blocker |
| E1 | Tests for every §A bug | P0 | S | The suite catches none of them today |
| B5 | Image wait state 1 → 0 (the image is SRAM now) | P1 | S | **Pystone −4.18% measured at `f15327a`**; a one-constant change |
| B1 | Posted stores and pipelined loads in the core | P1 | M–L | `S_MWAIT` is 46% (AES) / 26% (Fannkuch) |
| B11 | GC allocation zeroing at one store per cycle | P1 | S | Allocator wait is 17.5% of Fannkuch |
| B12 | Stream the short-list engine like `mpy_ca` | P1 | S–M | Short-list wait is 12.2% of Fannkuch |
| B2 | Less call/return frame-header traffic | P1 | M | Call+return is about 330 cycles; frame service is 20% of AES |
| B3 | Skip `S_FETCH` after fall-through ops | P1 | S | `S_FETCH` is 6.5% (AES) / 9.4% (Fannkuch) |
| B7 | `abs()` as a core native using `ALU_ABS` | P1 | S | `abs(float)` 635 → about 30 cycles (estimate) |
| B9 | Map-lookup cache for globals and attributes | P1 | M | `S_LK*` is 7.0% of AES, plus its memory waits |
| C2 | Binary32-native FPU | P1 | L | About 61K of 88K ALU cells; about 2× fewer div/sqrt cycles |
| D2 | Precompute scoreboard range ends | P1 | S | Three 32-bit adders on the plateau path `timing_10ns.md` names |
| D3 | Reset synchronizer; no logic on async resets | P1 | S | Two `SYNCASYNCNET` lint warnings |

---

## 2. What was run

Environment: Ubuntu 24.04, Python 3.13, Verilator 5.038, MicroPython
v1.29.0 oracle (i686, x87, as `variants/upycore/build.sh` builds it), plus a
second oracle built with `-msse2 -mfpmath=sse`. Yosys 0.70 (YoWASP) was used
for generic area on the committed `synth/hammer/converted/*.v`.

| Check (`f15327a` unless noted) | Result |
| --- | --- |
| Host tests (`upycore/tests/*`, `tools/test_runtime_profile.py`) | All pass |
| `compiler_suite.py` | **FAIL (exit 1)**: 504 files, 500 byte-exact, 3 float spelling, **1 differ** (`math_funcs.py`, E7). At `aca1b5e`: 491 files, 488 byte-exact, 3 float spelling, 0 differ |
| `unit_tests.py` | **29 / 29 pass**, including `mpy_boot` (`timing_10ns.md` reports it timing out in its environment) |
| `hw_tests.py --area all` (mpy-cross) | **494 / 494 pass** (68 min at `-j 3`), including `calls/star_wide_oom`, `containers/shortlist_methods`, and all 53 `compiler` programs. The uPy2 (`--compiler mpyc`) pass was not run in full |
| `hw_tests.py --check-goldens` | 482 pass, 10 skip (`oracle = false`), **1 FAIL: `containers/shortlist_methods`** (E7). `generators/gen_repr` passed in the full run but **fails when run alone** (E3) |
| x87 oracle vs SSE oracle on all 478 oracle-backed suite programs | **0 differ** |
| `verilator --lint-only -Wall` on `mpy_soc` | 0 errors; 225 UNUSEDPARAM, 56 UNUSEDSIGNAL, 22 WIDTHEXPAND, 6 PINCONNECTEMPTY, 5 WIDTHTRUNC (`mpy_shortlist.sv:55,108`, `mpy_gc.sv:348,578`), 1 UNOPTFLAT, **2 SYNCASYNCNET** (`sys_rst_n`, `u_gc.rst_n_i`). `mpy_core` has blanket `lint_off`, so its own warnings are hidden |

### 2.1 Measurements

**Microbenchmarks** at `f15327a`. Cycles per operation, loop overhead
subtracted. The script is in Appendix A.

| Operation | Cycles | Operation | Cycles |
| --- | ---: | --- | ---: |
| `y = x` (LOAD_FAST + STORE_FAST) | 5.9 | `abs(float)` | **635** |
| `x + x` (int) | 18 | complex `+` | **5,484** |
| `x * x` (small int) | 24 | complex `*` | **5,638** |
| `x // 3` | 24 | complex `/` | **5,857** |
| float `+` | 23 | `abs(complex)` | **4,361** |
| float `*` | 25 | complex `z ** 2` | **21,544** |
| float `/` | 57 | `L[1]` | 25 |
| `f ** 0.5` (hardware sqrt) | 62 | `D[1]` | 42 |
| empty `while` iteration | 45.8 | call `g(x)` + return | **330** |
| | | `L.count(1)` | 1,021 |

**Profiles** from `runtime_profile.py` (default kernels):

| Kernel | `aca1b5e` cycles | `f15327a` cycles | `S_MWAIT` | memory_response_wait | call_frame_service | allocator_wait | `S_SL_WAIT` | `S_FETCH` | `S_DEC` | `S_LK*` | Cycles/bytecode |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| misc_aes | 59.6 M | 2.29 M | 46.4% | 31.5% | 20.4% | 0 | 0 | 6.5% | 5.6% | 7.0% | 17.8 |
| bm_fannkuch | 44.2 M | 1.56 M | 25.7% | 17.2% | 0.1% | 17.5% | 12.2% | 9.4% | 7.0% | 0.1% | 14.2 |

The scratch-image swap (`S_SCR*`) is 0.35% or less. Do not spend effort
there.

**Image wait state 1 → 0** (B5). `timing_bench.py` at `f15327a`, same image
on both simulators:

| Case | Before | After | Change |
| --- | ---: | ---: | ---: |
| int_add | 62,477 | 61,417 | −1.70% |
| int64_mul | 112,542 | 109,483 | −2.72% |
| int_to_float | 1,584,534 | 1,477,475 | −6.76% |
| float_add | 67,485 | 66,425 | −1.57% |
| int_true_div | 99,475 | 98,417 | −1.06% |
| **pystone (300 loops)** | 12,118,317 | 11,611,775 | **−4.18%** |

On a scratch simulator with the wait state at 0 (built from `aca1b5e`),
the `smoke`, `alu`, `calls`, `containers`, `strings`, `gc` and `memory`
areas passed: 229 of 229.

**Generic area** (Yosys `synth`, hierarchical, `converted/mpy_alu.v` at
`f15327a`): `mpy_alu` is 87,858 cells.

| Block | Cells |
| --- | ---: |
| `upycore_fp_pow` | 20,119 |
| `upycore_fpu` sequencer | 16,242 |
| `upycore_mul` (int 64×64) | 8,367 |
| `upycore_umul_seq` (75×53 FP significand) | 7,008 |
| `mpy_alu` glue | 6,917 |
| `upycore_fp_divrem` + its `udiv_seq` | 5,071 + 3,216 |
| `upycore_fp_add` | 4,640 |
| `upycore_div` + its `udiv_seq` | 3,663 + 2,548 |
| `upycore_int_alu` | 3,411 |
| `upycore_fp_mul` | 3,394 |
| `upycore_ipow` | 1,847 |
| `mpy_f32_narrow` + 2 × `mpy_f32_widen` | 787 + 628 |

Floating point is about 61K cells (70%). Flattened, the ALU is 79,121
cells: 8.7K cells (10%) are dead complex logic, which only cross-boundary
constant propagation removes.

---

## A. Numeric correctness

All of these are user-visible wrong answers compared with the pinned
MicroPython oracle, and all reproduce at `f15327a`. None is caught by the
suite; E1 adds the tests. Do A7 first, so the reference is a strict
binary32 one.

### A1. `abs(complex)`: wrong values, about 4,400 cycles — P0, S (then B6)

**Evidence.**
- `upycore/firmware/ops.py:727` runs `return _fsqrt(re * re + im * im)`.
- `_fsqrt` (`floatfmt.py:570`) is 12 Newton steps from `x/2` (or `x` when
  `x <= 1`). Far from the root each step only halves the guess, so it
  converges only for `|z|` in about [2e-3, 5e2]. For `inf` it returns NaN
  (`inf/inf`).

| Expression | Device | Oracle |
| --- | --- | --- |
| `abs(complex(1e10, 0))` | 1.2207032e+16 | 1e10 |
| `abs(complex(1e-10, 0))` | 0.00024414064 | 1e-10 |
| `abs(1e5+1e5j)` | 2444136.4 | 141421.36 |
| `abs(123456+0.5j)` | 1863250.4 | 123456.0 |
| `abs(3e20+4e20j)` | nan | inf |

The FPU already has a correctly rounded square root: float `** 0.5` goes
to `S_POW_SQRT` (`upycore_fpu.sv:325`, `br == UPY_F64_HALF`).
`upycore/runtime/math.py:143` (`math.sqrt`) already uses `x ** 0.5`. The
FPU also has an `S_HYP_*` hypot sequence (`upycore_fpu.sv:142`), but
`mpy_alu.sv:380` passes `complex_i(1'b0)`, so it is unreachable.

**Change.**
1. In `floatfmt.py`, keep the `x < 0 → NaN` branch and replace the rest of
   `_fsqrt` with `return x ** 0.5`. A binary64 sqrt of an exact binary32
   input, rounded to binary32, is correctly rounded (53 ≥ 2·24+2), so this
   is bit-exact with the `sqrtf` that `objcomplex.c:119` uses.
2. Do **not** wire up `S_HYP_*`. It is CPython's scaled `hypot`, which
   returns 5e20 for `abs(3e20+4e20j)`; MicroPython overflows to `inf`.
   Delete it with C3.
3. B6 moves this into microcode for speed.

**Validated in this review.** With change 1 applied to an in-memory copy
of the firmware, the device matched the SSE oracle bit-for-bit on (3,4),
(1e10,0), (1e-10,0), (1e5,1e5), (0.001,0.002), (123456,0.5), (3e20,4e20),
(0,−0), (1e-25,1e-25), (inf,1) and (nan,1).

**Check.** E1 `complex_abs`.

### A2. Complex power and negative-base fractional power — P0, M

**Evidence.** `_cpow` (`ops.py:583`) uses `_fsin`/`_fcos`/`_fexp`/`_flog`/`_fatan2`
(`floatfmt.py:585-690`):
- `_fsin` (`:666`) multiplies `zp` by `x*x` each step but never divides by
  the running factorial, so it is not a Taylor series.
- `_flog` uses 14 terms of `ln(1+z)` for `z` in [0, 1). The error is about
  0.05 near 1.
- `_fatan` uses 11 arctan terms. The error is about 0.04 near 1.

| Expression | Device | Oracle |
| --- | --- | --- |
| `(1+2j)**2` | (18052.986-2817.6172j) | (-3.0000004+3.99999968j) |
| `(2+0j)**2` | (-6.1946736+0j) | (4+0j) |
| `1j**2` | (1.5486717+120173.304j) | (-1-8.742278e-08j) |
| `(-8.0)**(1/3)` | (-14823.649+1.7879728j) | (0.99999992+1.73205084j) |

**Change.**
1. Replace the five helpers with the `lib/libm` binary32 kernels that
   `upycore/runtime/math.py` already ports (`sin`, `cos`, `exp`, `_log`,
   plus an `atan`/`atan2` port of `lib/libm/atanf.c`/`atan2f.c`). Either
   move the kernels into firmware and have `runtime/math.py` call them, or
   duplicate them. Firmware cannot import a runtime module.
2. Follow `objcomplex.c` `MP_BINARY_OP_POWER` step for step, including
   `0**0`, `0**z` and the error text.
3. These kernels are within 1 ulp of glibc, not bit-exact (see
   `known_limitations.md`). Write the E1 tests to print with `'%.5g'`.
4. With `atan2` in place, also add `math.atan2` and `cmath.phase`/`polar`/
   `log`/`sqrt`, which `known_limitations.md` lists as missing because of
   it.

**Check.** E1 `complex_pow`, plus a host check of each kernel against
Python's `math` on 10^5 random binary32 inputs (≤ 2 ulp).

### A3. Complex division order — P0, S

**Evidence.** `ops.py:572-573` computes
`((ar*br + ai*bi)/d, (ai*br − ar*bi)/d)`. `objcomplex.c:196-213` instead
scales the divisor, then multiplies:

```c
d = br*br + bi*bi;
br /= d;
bi /= -d;
real = ar*br - ai*bi;
imag = ar*bi + ai*br;
```

For `(1.5+2.5j)/(0.5+1j)`, the device gives (2.6-0.2j); the SSE oracle
gives (2.6-0.200000052j).

**Change.** Replace `ops.py:573` with:

```python
br = br / d
bi = bi / -d
return _complex(ar * br - ai * bi, ar * bi + ai * br)
```

**Validated in this review.** All 5 division probes, including both
special branches, matched the SSE oracle. The x87 oracle still differed on
one of them, which is A7.

### A4. `abs()`: wrong for `-0.0` and bools; 635 cycles — P0 (correctness) / P1 (speed), S

**Evidence.** `builtins.py:199` returns `-x if x < 0 else x`:

| Expression | Device | Oracle |
| --- | --- | --- |
| `abs(-0.0)` | -0.0 | 0.0 |
| `abs(True)` | True | 1 |

`ALU_ABS` exists in `mpy_alu.sv`: it clears the sign for floats and maps
ints to POS/NEG, which handles int64 overflow. Nothing reaches it, because
`abs` is a builtin, not a unary bytecode.

**Change.**
1. Firmware fix:
   - floats: `_frombits(_u32(_pay(x)) & 0x7FFFFFFF)` (the oracle uses
     `signbit`);
   - bools: convert to int first.
2. **Native (P1):** add `ABI_N_ABS`.
   - In `S_NAT_A`, a `numlike` argument goes through `S_NUM` with
     `alu_op = ALU_ABS` and `n_un = 1`.
   - COMPLEX goes to the B6 microcode once that exists.
   - Everything else falls back to firmware `abs` (`__abs__`).
   - Register it in `upycore/tools/mpy_abi.py` `NATIVES`, as `len` is.
3. Decide `abs(-2**63)`: the oracle wraps (`mp_obj_new_int_from_ll(-val)`);
   the ALU raises OverflowError. Match the oracle, or document it.

**Check.** E1 `abs_edge`. Microbench `abs(float)` under 40 cycles.

### A5. `round()` — P1, S

**Evidence.** `builtins.py:266` converts every argument with
`number + 0.0`.

| Expression | Device | Oracle |
| --- | --- | --- |
| `round(16777217)` | 16777216 | 16777217 |
| `round(7, 2)` | 7.0 | 7 |
| `round(1e20)` | a float, `1e+20` | `ValueError: float too big` |

**Change.** Port `mp_builtin_round` (`vendor/micropython/py/modbuiltins.c:461`):
- an int is returned as is;
- an int with `ndigits` rounds in integer arithmetic;
- a float is `nearbyint`, then int conversion with the oracle's error;
- a float with `ndigits` is `nearbyint(val*mult)/mult`.

**Check.** E1 `round_edge`.

### A6. Host `mpy-cross` folds float constants in binary64 — P0, S

**Evidence.**
- `vendor/micropython/mpy-cross/mpconfigport.h:77` sets
  `MICROPY_FLOAT_IMPL_DOUBLE`, and `MICROPY_COMP_CONST_FLOAT` is on.
- `1/3` is folded to `0.3333333333333333`, stored as text, and parsed on
  the device to 0x3EAAAAAA. The oracle folds in binary32 and gets
  0x3EAAAAAB.
- So on the device, `print(1/3)` gives `0.3333333` and
  `1/3 == 1.0/3.0` is `False`.

Commit `14d8432` ("Link mpy-cross's folded pi as binary32 pi") patched one
symptom of this.

**Change.** Build the repo's `mpy-cross` with
`-DMICROPY_FLOAT_IMPL=MICROPY_FLOAT_IMPL_FLOAT`, through
`variants/upycore/build.sh build_mpy_cross` or `unix-port.patch` (or turn
`MICROPY_COMP_CONST_FLOAT` off). Then:
- rebuild `Dockerfile.oracle`;
- re-check `tools/mpy_link.py` (the `14d8432` special case may become
  unnecessary) and `compiler/prepare.py`;
- `compiler_suite.py`'s 3 "float spelling" differences should go away, or
  be explained.

**Check.** The device prints `0.33333334 True` for
`print(1/3, 1/3 == 1.0/3.0)`, and the suite passes with both compilers.

### A7. The oracle uses x87 extended precision — P0, S

**Evidence.**
- The oracle binary has 596 x87 instructions and no SSE (`objdump`). With
  x87 (`FLT_EVAL_METHOD=2`), binary32 expressions keep 80-bit
  intermediates, which real binary32 MCUs (Cortex-M4F, ESP32) do not.
- An oracle rebuilt with `-msse2 -mfpmath=sse`:
  - gives identical output on **all 478** oracle-backed suite programs;
  - agrees with the **device** on probes where the x87 oracle disagreed:
    `abs(0.001+0.002j)` is 0.0022360682, and `2**62/3` prints
    `1.5372288e+18`, which is correct for the binary32 value
    1.5372287186e18.

**Change.**
1. In `variants/upycore/mpconfigvariant.mk`, add
   `CFLAGS_EXTRA += -msse2 -mfpmath=sse`.
2. Rebuild the oracle image and run `make regen-goldens` (expect no
   diffs).
3. Note the choice in `mpconfigvariant.h` and in the README.

`known_limitations.md` blames a `random.uniform` difference on x87; it
goes away with this change.

**Check.** `objdump -d .../micropython | grep -c xmm` is greater than 0,
and `--check-goldens` is clean.

### A8. Minor parity — P3

- `divmod(2**40, 2)` works on the device; the oracle raises `TypeError` (a
  longlong-build limitation). Keep the device behavior and document it.
- `int()` parsing and `dict()` update entries are still open in
  `known_limitations.md`. Fix them per that file.

---

## B. Performance (cycles)

Check `planning/runtime_optimization_*` before starting, and coordinate on
`mpy_core.sv`, which every item here touches.

### B1. Non-blocking core memory interface — P1, M–L

**Evidence.**
- `rd()`/`wr()` (`mpy_core.sv:1651-1658`) set `m_req` and go to `S_MWAIT`
  (`:1872`), which waits for `m_ack_i`.
- One access therefore takes the issue cycle plus 3 cycles of wait (grant,
  `phase_r`, ack): about 4 cycles, and 5 for image reads (B5). Stores pay
  the same.
- `mpy_mem` accepts one request per port per cycle.
- `S_MWAIT` is 46.4% of AES and 25.7% of Fannkuch.

The multi-word sequences that pay this one word at a time:

| Sequence | States |
| --- | --- |
| Frame-header spill/fill, 17 words each | `S_SP_H`, `S_FL_H` |
| Locals clear | `S_LCLR`/`S_LCLR2` |
| Stack spill/fill | `S_SP_R`, `S_FL_S` |
| Function object reads | `S_CF`…`S_CF4` |
| Raw-code header reads | `S_CF_SIG`, `S_CF_ARGS`, `S_CF_CHK` |
| Block writes | `S_WB` |
| Scratch images | `S_SCR` |
| Short-list states | |

**Change.**
1. Bring the core port's grant out as `m_gnt_i`, from `m_gnt[P_CORE]` in
   `mpy_soc`. `mpy_soc` keeps one `c_pend`, so the core must never have
   two requests ungranted at once.
2. **Posted stores.** `wr()` waits for the grant, not the ack, and counts
   outstanding acks. The port completes in order, so a later load sees the
   store.
   - A fault arrives with a later ack. Keep a 2-deep FIFO of in-flight
     addresses, or return the address with the fault, so the halt still
     reports it.
   - Drain the outstanding stores before `S_GC_T`, before reading
     `ca_idle_i`, and before shipping CA or short-list commands whose
     sources include those stores.
3. **Burst helper.** Issue up to 2 accesses per cycle in flight and steer
   the read data by index. Use it for the sequences above. Single loads
   stay blocking (`rd()`).
4. Faster single accesses would need SRAM data returned unregistered or
   the request launched combinationally. Both lengthen the paths
   `timing_10ns.md` lists, so don't.

**Check.**
- The suite passes, also with `--sim-arg +CA=0 --sim-arg +AALU=0`.
- `runtime_profile.py`: `S_MWAIT` share roughly halves on AES.
- Microbench `call_g` drops below 200 cycles (estimate: a header
  spill/fill goes from about 68 to about 19 cycles).

### B2. Call/return frame traffic — P1, M (after B1)

**Evidence.**
- Each call writes all 17 header words (`S_SP_H`, `mpy_core.sv:2174`;
  `hdr_word()` at `:1547`).
- Each return reads all 17 (`S_FL_H`, `:2205`).
- All `nloc` callee locals are written NULL one at a time, two states plus
  a wait each (`S_LCLR`/`S_LCLR2`, `:2094-2096`), including the ones
  argument binding overwrites next.
- Call service is 20% of AES. A trivial call+return is 330 cycles.

**Change.**
1. **Static/dynamic split.**
   - Static words (fprev, rc, glb, loc, fun, qbase, cbase, gen) are written
     once per frame, before anything can observe the frame in memory: the
     first spill or `S_GC_T`.
   - Later spills write only the 9 dynamic words.
2. **Locals clear.** Clear only `[n_bound, nloc)`, and with the B1 burst.
3. **Optional, L: shadow header bank.** One or two 17-word copies of the
   header (about 600 flops each) take the header on a call and give it back
   on a return.
   - Flush the bank to memory before `S_GC_T`, a raise or traceback walk,
     generator save, firmware frame introspection, and when it is full.
   - Measure before committing the area.

**Check.** The `calls`, `exceptions`, `generators` and `gc` areas pass.
`call_g` below 120 cycles after steps 1–2 plus B1 (estimate).

### B3. Skip `S_FETCH` after fall-through ops — P1, S

**Evidence.** Since `4f492bb`, `S_FETCH` (`mpy_core.sv:2430`) does three
things:
- runs the spill, reload, AALU and CA-fault checks;
- registers the aligned window (`dq_bytes <= d_bytes`);
- goes to `S_DEC`, which decodes from those flops.

Every bytecode takes at least `S_FETCH` + `S_DEC` + `S_EXEC`. `S_FETCH` is
6.5% of AES and 9.4% of Fannkuch.

Do **not** merge `S_FETCH` into `S_DEC`. That would put the window shift
back in front of the decoder, which `4f492bb` removed for timing.

**Change.** In `S_EXEC`, `pc` already points at the next instruction
(`S_DEC` did `pc <= pc + d_len`).
1. For ops that finish in `S_EXEC`, leave `pc` unchanged and go to
   `S_FETCH`: LOAD_FAST hit, small-int and constant pushes, POP_TOP, DUP,
   ROT, NOP. For these, also register `dq_bytes <= d_bytes; dq_n <= d_n`
   when `fe_avail != 0` and `!ca_fault_i`, and go straight to `S_DEC`.
   - `d_bytes` comes from flops (`pc`, the fetch queue), so this is the
     same register-to-register path `S_FETCH` already has.
2. In `S_DEC`, move the spill, reload and AALU checks ahead of the decode
   (they compare `sp`/`has_link` flops). When one fires, take the
   `S_FETCH` action instead of decoding.

**Check.**
- The suite passes, and `trace_*` order and `ops` counts are unchanged.
- `S_FETCH` share drops by more than half (estimate: 3–5% fewer cycles).
- Run `clock_bench.py` and `mpy_synth.py --depth` to confirm no new deep
  path.

### B4. Skip `S_NUM`/`S_NUM_B` when no operand is boxed — P2, S

**Evidence.** A numeric op goes `S_BIN` (`:3851`) or `S_UN` (`:3838`), then
`S_NUM`, `S_NUM_B` and `S_NUM_GO` (`:3910-3924`). The middle two states
only latch `sx64(ival(t[i]))` unless an operand is INT64. `NUM*` states are
4.3% of AES.

**Change.** In `S_BIN`/`S_UN`, when neither operand is
`ABI_TAG_INT64`, latch `na`, `nb`, `na_f` and `nb_f` from `rf` and go to
`S_NUM_GO`. Keep the INT64 path. `aalu_safe()` keeps reading latched
values.

**Check.** The suite passes; `int_add`/`float_add` are 2 cycles faster each.

### B5. The image no longer needs a wait state — P1, S (measured)

**Evidence.**
- `mpy_defs.svh:117` has `MPY_FLASH_WAIT_STATES = 1`, applied to every
  image access (`mpy_mem.sv` `phase_r`).
- The image now sits in the same SRAM blocks as data.
- `mpy_memory_map.md:47-48` still says "Flash adds
  `MPY_FLASH_WAIT_STATES`".

Measured at `f15327a` with 0: **pystone −4.18%**, and −1.06% to −6.76% on
the arithmetic loops (§2.1). Subsets pass (229 of 229).

**Change.**
1. Set the default to 0, keeping the parameter for a future external
   flash.
2. With 0, `hold_r` in `mpy_mem` is dead. Drop it, or leave it for
   synthesis to remove.
3. Rename "flash" to "image region" in `mpy_mem.sv` and
   `mpy_memory_map.md`, keeping the ABI names.

**Check.** The full suite passes; `clock_bench.py`/`timing_bench.py`
before and after go into `timing_10ns.md`. Same SRAM, same paths, so no
timing impact.

### B6. Complex arithmetic in microcode — P2, M–L (after A1–A3)

Complex `+ − * /`, `abs`, `==` and unary `-` go
`S_BIN_FB` → `ABI_HOOK_BINOP` → `_binop` → `_num_binop`, which costs about
5,500 cycles.

**Change.** In `S_BIN`, when one operand is COMPLEX and the other is
`numlike` or COMPLEX:
1. Load the parts: 2 words each. INT/FLOAT operands become `(x, 0)`.
2. Run binary32 ALU ops in exactly the A3/`objcomplex.c` order:
   - add/sub: 2 ops;
   - mul: 4 MUL + 2 ADD/SUB;
   - div: the A3 sequence;
   - abs: 2 MUL + ADD + sqrt;
   - eq/ne: 2 compares.
3. Allocate 2 words, store them, and push.
4. For sqrt, add `ALU_SQRT` to `mpy_alu` (the FPU's `S_POW_SQRT`), or use
   `ALU_POW` with `0.5f`.
5. Power and floor-div/mod stay in firmware.

Expected (estimate): 50–120 cycles per op.

**Check.** `complex*` suite programs plus E1. Microbench complex `+`/`*`
under 150 cycles.

### B7. Natives for hot builtins — P2, S each

After A4's `abs`, do `divmod(int, int)`: `upycore_div` already returns the
quotient and remainder together, so this is one ALU op plus a 3-word tuple
alloc. Then profile `min`/`max`/`round` on two numbers.

### B8. Integer multiply skips zero chunks — P3, S

`upycore_mul` always takes `64/STEP + 1` = 5 clocks, even for 31-bit small
ints (`int_mul` costs 24 cycles against `int_add`'s 18). Count the
significant chunks of the multiplier, as `upycore_div` skips leading zeros,
and stop early; the top chunk stays signed. Check with `tb_upycore_mul` at
all three STEP values plus a small-operand sweep.

### B9. Map-lookup cache — P1, M

**Evidence.** Global, name and attribute lookups run `S_HASH`, then
`S_LK_HM` (modulo), then probe reads. `S_LK*` is 7.0% of AES, plus its
memory waits.

**Change.** Add a small direct-mapped cache, like upstream
`MICROPY_OPT_MAP_LOOKUP_CACHE`:
- About 64 entries of `{tag, slot}`, indexed by `map_addr ^ qstr_id`.
- On a lookup, read `table[slot].key`. If it equals the qstr, it is a hit;
  otherwise probe normally and refill the entry.
- The cache validates itself: a stale slot only misses, as long as `slot`
  is bounds-checked against `alloc`.
- Placement is untouched, so iteration order is unaffected.
- Area: about 2K flops (estimate).

**Check.**
- The suite passes. `S_LK*` halves on AES.
- Add a test that deletes, re-adds and resizes dicts between attribute
  reads.

### B10. GC mark reads — P3, M

`mpy_gc` now pipelines the table update during marking (`bd8cf62`). The
root and object word reads are still one per round trip. GC is under 0.1%
of the profiled cycles, so do this last.

### B11. GC allocation zeroing at one store per cycle — P1, S

**Evidence.** `mpy_gc.sv:456-476`. `G_ZERO` issues one zero store, then
`G_ZERO_W` waits for its ack before the next, so each word takes about 4
cycles. An n-word allocation spends about 4n cycles zeroing.
`allocator_wait` (`S_AL_W`) is **17.5% of Fannkuch**.

**Change.** Stream the zero stores: issue the next one as soon as the port
grants, and count acks. This port has the highest priority in `mpy_mem`,
and stores complete in order. Raise `alloc_done_o` when the last ack
arrives. Expected (estimate): 4n to about n + 2 cycles. Optionally, let the
core request a no-zero allocation for destinations it fully overwrites
before anything can read them (CA copy targets). It must then zero only
the tail it does not copy.

**Check.** `tb_mpy_gc`, the `gc`/`memory` areas, and the Fannkuch
`allocator_wait` share before and after.

### B12. Stream the short-list engine — P1, S–M

**Evidence.**
- `mpy_shortlist.sv:104-110`: `READ_REQ` waits for the grant, then
  `READ_WAIT` waits for the ack before the next read. Writes do the same.
- `S_SL_WAIT` is **12.2% of Fannkuch**.
- `mpy_ca` already streams with a read-ahead buffer at two cycles per word
  (`mpy_ca.md`).

**Change.** Use the `mpy_ca` scheme:
- reads issued back to back while the buffer has room;
- responses counted in order;
- writes from the buffer back to back.

The "all reads before the first write" rule stays: it is a buffer-fill
barrier, not a reason to serialize.

**Check.** `tb_mpy_shortlist` (both `MAX_ELEMS`), the `containers` area,
`shortlist_bench.py`.

---

## C. Area and power

### C1. GC allocation table — done (`bd8cf62`)

It went from 61,280 flops to a `fakeram_d600_w64` macro (`timing_10ns.md`:
5.83 mm² down to 0.107 mm² in the estimate flow). Remaining:
- add the macro to `make sram` and the floorplan (the open item in
  `timing_10ns.md`);
- document in `mpy_memory_map.md` that the heap is capped at
  `GC_TABLE_BYTES` (19,200 blocks) even when the image leaves more room.

### C2. Binary32-native FPU — P1, L

**Evidence.**
- Floats are binary32 (`MICROPY_FLOAT_IMPL_FLOAT`).
- `mpy_alu` widens every operand to binary64, runs `upycore_fpu`, then
  narrows the result.
- The FPU holds a 75×53 significand multiplier, a 33-cycle radix-4
  divider/sqrt, a 53-bit adder and a binary64 power unit.
- FP is about 61K of the ALU's 88K cells.
- `timing_10ns.md` added a result register to FP add, mul and div
  (+1 cycle each) to meet timing at this width.

**Change.** A binary32 datapath behind the same `mpy_alu` interface:

| Unit | Binary32 version |
| --- | --- |
| add/sub | 24-bit significand, 2–3 stages |
| mul | 24×24, 1–2 cycles |
| div/sqrt | About 15–17 cycles at radix 4 |
| fmod | Unchanged |
| pow | 2^(y·log2 x) with about 40-bit internals |

Also:
- Drop `mpy_f32_widen`/`mpy_f32_narrow` and `A_FNAR`, which saves 1 cycle
  per float op.
- Keep RNE, subnormals, and the existing NaN/inf decode rules.
- Do A7 and E2 first.

**Check.** E2 passes, the suite passes, ALU about 40K cells or less
(estimate), float div/sqrt about 2× faster in `timing_bench.py`.

### C3. Dead complex logic in `upycore_fpu` — P1, S

**Evidence.** The `S_CADD/CMUL/CDIV/CREC/HYP` states (`upycore_fpu.sv:137-142`),
their decode, the 128-bit operands and the upper 64 result bits are
unreachable from `mpy_alu.sv:380`. They cost 8.7K cells unless the tool
propagates constants across boundaries, and they implement CPython
semantics.

**Change.** Delete them, and fix the header comment, which describes
CPython complex support and cites a nonexistent `docs/alu.md`. C2 subsumes
this.

**Check.** `tb_mpy_alu`, `tb_mpy_numeric`, `tb_upycore_fp_subnormal`, and a
lower cell count.

### C4. RTL not in the SoC — P1, S

| Module | Status | Recommendation |
| --- | --- | --- |
| `mpy_container.sv` (1,186 lines) | Not instantiated; superseded by `mpy_collection` | Delete it with its bench and its references: `Makefile` `DC_TOPS`, `unit_tests.py`, `mpy_synth.py`, `synth/dc/README.md`, `synth/hammer/README.md` |
| `mpy_regfile.sv` | Not instantiated; only `tb_mpy_value` uses it | Delete it, keeping the value-encoding checks |
| `mpy_prelude_decode` (`mpy_decode.sv`) | Only `tb_mpy_decode` uses it | Move it to `tb/` as a reference model, or delete it |
| `mpy_periph`, `mpy_irq`, `mpy_mmio_pkg` | Unit-tested, **not connected**: the chip has no UART, GPIO, timer or IRQ. `mpy_peripherals.md` reads as if it does | Integrate them (an MMIO window at `0x4000_0000` on the core data path, a `machine` module, the IRQ hook at bytecode boundaries), or mark them "not integrated" everywhere and leave them out of v1 |
| `TYPE_CACHE` in `mpy_collection` | Off by default; 3.1K cells for 0.05% cycles | Remove it, or keep it labeled experimental |

### C5. Clock gating and idle power — P2, S

- The flow and the RTL have no clock gating. 5,353 of the 5,398 flops in
  the flattened ALU are enable-loaded (`DFFE`).
  - Turn on Genus clock-gating insertion through Hammer
    (`synthesis.clock_gating_mode: auto`, or the class equivalent).
  - Add a core-level enable for `S_HALT`.
- Quantify with `genus_reports.tcl` and the SAIF in
  `synth/hammer/activity/`. The SAIF predates the current RTL, so
  regenerate it.

### C6. Fetch after taken jumps — P3

`fetch_empty` is 0.8% (AES) to 2.4% (Fannkuch). Revisit after B1/B3. Above
about 3%, add a 1-entry loop-target buffer `{target_pc, word}`.

---

## D. Timing (clock speed)

The last post-route result is **18 ns**. `timing_10ns.md` estimates about
10.5 ns at `f15327a` (open flow, typical corner, scaled). It names the
remaining plateau, at 7.1–7.5 ns in the estimate flow:
- the core state machine's outputs (`m_addr`, `m_be`, `wret`, `st`, `rstk`);
- the copy engine's grant response;
- the SRAM enables behind the scoreboard check and `mpy_mem` arbitration.

**No post-route 10 ns result exists.** The README and docs must say so
(F2).

### D1. `mpy_mem` address arithmetic — P2, S

**Evidence.** `8c0eecf` registered `image_words`/`data_words` and took the
block from `sw`'s low bits. Still in the grant cycle:
- the row add `(32'(sw) + image_words) >> BS` (`mpy_mem.sv:157`);
- the 32-bit bound compare `32'(sw) >= data_words` (`:145`).

**Change.** Map the data region top-down: physical word `= ~sw[16:0]`.
`MPY_MEM_WORDS` is 2^17, so this is free.
- The block is `~sw[1:0]` and the row is `~sw[16:2]`: no adder.
- The bound check becomes a 17-bit compare.
- The image stays bottom-up, so boot load and clear are unchanged.

**Check.** `tb_mpy_shared_mem`, `tb_mpy_soc`, the suite, and the estimate
flow before and after.

### D2. Scoreboard range ends — P1, S

**Evidence.**
- `mpy_collection.sv:103-107` compares the core's address against
  `queue[i].hashes + (queue[i].sn << 2)`, `queue[i].header + 16` and
  `queue[i].source_header + 16`. That is three 32-bit adders per entry, in
  front of the compare.
- The result gates `m_req[P_CORE]` (`mpy_soc.sv:306`) and then `mpy_mem`
  arbitration. That is the plateau path `timing_10ns.md` names.
- `src_end`/`dst_end` are already precomputed.
- The short-list engine adds its own `chk_busy_o`.

**Change.**
1. Compute `hashes_end`, `header_end` and `source_header_end` at push time
   and store them in `command_t`.
2. Check the same for `mpy_shortlist`'s ranges.
3. If the plateau remains, register the check against the core's next
   address one cycle early. That costs the cycle `timing_10ns.md`
   declined, so measure with `clock_bench.py`.

**Check.** `tb_mpy_collection`, `tb_mpy_map_engine`, `tb_mpy_shortlist`,
the `containers` area, and the estimate flow.

### D3. Reset structure — P1, S

**Evidence.**
- The primary `rst_n_i` is used directly as an async reset everywhere,
  with no synchronizer, and the flow false-paths it
  (`make_hammer_design.py:90`).
- Logic drives async resets:
  - `mpy_boot`: `rst_n_i && mem_ready` (`mpy_soc.sv:141`);
  - `mpy_gc`: `rst_n_i && boot_done && !boot_err_o` (`:199`), where
    `boot_err_o` includes the comparator `layout_error`.
- Lint reports `SYNCASYNCNET` on `sys_rst_n` and on `u_gc.rst_n_i`.

**Change.**
1. Put a 2-flop reset synchronizer at the `mpy_soc` top: assert
   asynchronously, deassert synchronously.
2. Make every derived reset a flop output. Better, replace gated resets
   with synchronous start enables.
3. Give `sys_rst_n` recovery/removal checks in STA, not a false path.

**Check.** `tb_mpy_soc` with and without `--nand`, `tb_mpy_boot`, the
suite. `SYNCASYNCNET` is gone.

### D4. State-machine output plateau — P2, M

`sp` → `m_addr` (7.51 ns estimate) comes from about 30 short-list address
sources added to the core's address select (`timing_10ns.md`).

**Options:**
- Compute addresses one state early into a small set of registers
  (`a_next`), so `m_addr` selects from flops. This adds no cycle for
  states that already precede a memory state.
- Let Genus one-hot the about 470-state FSM; do not hand-encode it.
- Moving the short-list address generation into `mpy_shortlist` (B12)
  also removes those sources.

### D5. A real timing number — P1, M (needs the lab flow)

Run Genus/Innovus on `mpy_soc` at 10 ns, with the `fakeram_d32768_w36` and
`fakeram_d600_w64` macros, and record:
- commit, corner and macros;
- WNS/TNS before and after route;
- hold;
- area by hierarchy;
- SAIF power.

Then merge `timing_100mhz.md` and `timing_10ns.md` into one current doc.
Keep the history in an appendix.

---

## E. Tests, CI and test documentation

### E1. Tests for the §A bugs — P0, S

Add these to `upycore/programs/hw/alu/`. Generate the goldens from the
oracle after A7, and have each program print values.

| Program | Covers |
| --- | --- |
| `complex_abs.py` | 1e-30…1e30, inf/nan/±0 parts, overflow to inf |
| `complex_div.py` | Both special branches, the general case, divide by zero |
| `complex_pow.py` | Int, fractional and complex exponents; `0**0`, `0**z`, `(-8.0)**(1/3)`; printed with `'%.5g'` |
| `abs_edge.py` | `-0.0`, nan, bools, ints at 31/32/63-bit limits |
| `round_edge.py` | Ints with and without `ndigits`, huge floats raising, half-even, `round(x, n)` |
| `float_const_fold.py` | `1/3 == 1.0/3.0`, `0.1+0.2`, `2.0**-3`, mixed constant expressions |

The current `complex_ops.py` only checks `abs(3+4j) == 5.0`, which is
inside the range where Newton converges.

### E2. Randomized binary32 FPU bench — P1, M

`tb_mpy_alu` has **35 checks**. `tb_mpy_numeric` covers only conversions.
`tb_upycore_fp_subnormal` (12K) covers binary64 subnormals. Nothing checks
binary32 add/sub/mul/div/sqrt/fmod/floor/pow against a reference with
random vectors.

Add `tb_mpy_fpu32`:
- a C++ oracle in the style of `mpy_numeric_oracle.cpp`, built for SSE;
- 10^5–10^6 random and special-class vectors per op;
- `powf` may differ by ≤ 1 ulp; everything else must be bit-exact.

It must pass before and after C2.

### E3. `--check-goldens` is environment- and order-dependent — P1, S

**Evidence.**
- `generators/gen_repr.stdout` stores `<generator object 'named' at f7b5e180>`.
- It passed inside the full `--check-goldens` run, failed in an earlier
  full run on the same machine, and fails when run alone: "golden differs
  only by an address".
- Device runs mask addresses (`mask_output`); the golden check does not.
- `make test` runs `--check-goldens` whenever an oracle exists.

**Change.** Compare `mask_output(oracle)` with `mask_output(golden)` in
check mode, and only note address-only differences.

### E4. CI gaps — P1, S

`.github/workflows/all-tests.yml` runs host, unit and per-area hardware
jobs with both compilers. It does not run:
- `--check-goldens`. Add an oracle job, reusing the cached
  `Dockerfile.oracle` from `oracle-build.yml`.
- `upycore/tools/test_runtime_profile.py`. Move it to `upycore/tests/` and
  into `make test-host`.
- `mpy_image.py --check upycore/programs/mpy/phase1`, the `mpy_bytecode.md`
  "Phase 1 check". It passes, but nothing runs it.
- Lint. Add a job:
  - `verilator --lint-only -Wall` on `mpy_soc` with a checked-in waiver
    file;
  - drop the blanket `lint_off` block at the top of `mpy_core.sv`;
  - add `` `default_nettype none `` to every RTL file (none has it);
  - fix the 5 `WIDTHTRUNC`, the `mpy_ca.sv` `WIDTHEXPAND`s, and the
    `UNOPTFLAT` on `mpy_f32_narrow.jam`.
- A freshness check on `synth/hammer/converted/*.v` (E6).

Also:
- `planning/README.md` claims CI skips the hardware suite for markdown-only
  changes, but `all-tests.yml` has no path filters.
- `oracle-build.yml` triggers on the deleted branch `mpy_translation`.

### E5. Test documentation — P1, S

Add `TESTING.md`.

**Requirements:**
- Python ≥ 3.11 (`tomllib`).
- Verilator ≥ 5.032.
- `gcc-i686-linux-gnu` **and** the i386 loader (`libc6-i386`). Without the
  loader the oracle builds, then fails with a confusing
  `FileNotFoundError`.
- Optional: Yosys + yosys-slang, sv2v, OpenROAD/OpenSTA for the
  `timing_10ns.md` estimate flow.

**Each layer, how to run it, and what it covers:**
1. Host tests.
2. `compiler_suite.py`.
3. The RTL benches (list them).
4. The hardware suite: areas, both compilers, the golden rules, and the
   `oracle = false` and `mpyc = false` flags.
5. Golden checking.
6. The benchmark tools: `bench.py`, `bulk_bench.py`, `timing_bench.py`,
   `clock_bench.py`, `runtime_profile.py`, `perf_inventory.py` and
   `shortlist_*`.

**Also:**
- Run times: unit benches take about 7 minutes on 4 cores; the `compiler`
  area takes minutes per program.
- How to add a test and regenerate goldens.

### E6. Generated backend netlists — P2, S

`synth/hammer/converted/*.v` (about 1 MB) is committed, and `RTL_STAMP`
holds a commit hash. Either:
- generate the netlists inside the flow; or
- add a CI job that runs `convert_rtl.sh` with a pinned sv2v and fails on
  a diff.

Stamp them with a sha256 of the RTL inputs, not a commit hash.

### E7. The suite is not green under its own rules — P0, S

1. **`calls/star_wide_oom`.** `timing_10ns.md` records it failing ("490 of
   491 pass"). In this review it **passed** at `f15327a` (6,112,282
   cycles, Verilator 5.038).
   - Rerun it in the CI image (`Dockerfile`, Verilator 5.032) to see
     whether the result depends on the simulator or is already fixed.
   - Correct `timing_10ns.md` either way.
   - If it is simulator-dependent, find the nondeterminism (X propagation,
     `--x-initial`), and do not paper over it. The manifest checks reject
     xfail entries.
2. **`containers/shortlist_methods`** (`b381f58`). The device run passes,
   but the golden (`shortlist methods passed`) is not oracle output. The
   oracle fails the test's own assertion at line 28, because MicroPython's
   `list.insert(True, 9)` gives `[1, 2, 9]` (`list_insert` applies
   `MP_OBJ_SMALL_INT_VALUE` to the bool), so `--check-goldens` fails.
   Either:
   - drop the bool-index lines; or
   - make the device match the oracle and print the result.

   Goldens must be oracle output.
3. **`compiler_suite.py` exits 1 at `f15327a`**, so `make test-host` and
   CI's `host-tools` job fail.
   - It reports `504 file(s), 500 byte-exact, 3 float spelling, 1 differ`.
     The differing file is `hw/modules/math_funcs.py`, added with the
     runtime modules.
   - uPy2 spells the constant `1e-40` as `9.999999999999999e-41`;
     `mpy-cross` writes `1e-40`. The "float spelling" classifier does not
     accept this pair.
   - Fix one of:
     - uPy2's float repr, upstream in `vendor/upy2`;
     - the classifier, if both texts give the same binary32 on the device
       parser;
     - the test, by avoiding that literal.
3. **`generators/gen_repr`.** See E3.

---

## F. Documentation and publishing hygiene

### F1. License — P0, S

There is no `LICENSE` at the root or in `vendor/upy2`. Add a LICENSE, a
third-party `NOTICE`, and SPDX headers. The notice should cover:
- MicroPython (MIT, submodule);
- the ports of MicroPython C semantics and `lib/libm` kernels in firmware
  and `upycore/runtime/`;
- the BaseJump STL-compatible SRAM stand-in (original code, BaseJump
  interface; BaseJump is BSD-3);
- the Hazard3-derived files in `synth/hammer/activity/` (check its
  Apache-2.0 terms).

Keep class (NDA) files out, as `synth/hammer/README.md` already says.

### F2. README — P0, S

- Lines 8–10 say the 512 KiB SRAM holds the compiler and firmware.
  Lines 98–99 say "The frozen uPy2 compiler does not fit the image SRAM,
  so `compile`, `exec` and `eval` programs do not link". The 53-test
  `compiler` area links and runs. **Delete lines 98–99.**
- The last line ("`make test` covers a hello program and a raised
  `ValueError`") is stale.
- The "Accelerators" paragraph and `mpy_hash.md:9-10` say the hash units
  are "not yet connected to the SoC". In fact:
  - `mpy_hash` is in `mpy_bulk` and `mpy_map_engine`;
  - `mpy_hash_slot` is in `mpy_rehash_stream`, inside `mpy_bulk`;
  - all of it sits in `mpy_collection` in the SoC.

  Rewrite both.
- Add:
  - the short-list engine (`shortlist_engine.md`);
  - the runtime modules and their limits;
  - the requirements (E5);
  - the license (F1);
  - timing status ("18 ns post-route; about 10.5 ns estimated; 10 ns
    unproven");
  - peripheral status (C4).
- Layout table: add `upycore/tb`, `upycore/tests`, `upycore/compiler`,
  `upycore/runtime`, `upycore/synth`, `upycore/docs/benchmarks`, `docs/`,
  `vendor/upy2`.

### F3. `planning/` — P1, S

- `planning/README.md` points to `pycore/docs/`, `excore/docs/`,
  `pycore_firmware/`, `tools/gc_acceptance.py` and a "task hook". None
  exists.
- `cleanup_report.md` cites deleted files (`singlecore.zip`,
  `preprocess.py`, `image_from_source.py`, `pycore_core.sv`).
- `master_plan.md` is the old CPython-hart roadmap.

For the release:
- archive everything that is not an open plan (`runtime_optimization_*`,
  `perf_bench_coverage_*`, `shortlist_engine_status.md`, this review) under
  `planning/old/`;
- rewrite `planning/README.md`;
- re-validate or retire `cleanup_report.md`.

Also check `docs/paper/README.md` ("PyCore subsystems") and `.cursor/`
(keep it out of the release, or document it).

### F4. `known_limitations.md` — P1, S

It now covers `int()` parsing, `dict()` updates, the runtime modules and
`memoryview`. Also add:
- **Modules still missing** compared with the oracle: `struct`,
  `collections`, `time`, `json`, `re`, `errno`, `heapq`, `binascii`,
  `hashlib`, `os`.
- **Runtime modules are frozen only on a static `import`** (an AST scan
  in `mpy_build.py:301`). So `__import__('math')`,
  `exec('import math')` and on-device `compile` of an import fail with
  `ImportError` unless the program also imports the module statically.
- Complex-power accuracy (A2), the `divmod` difference (A8), no
  peripherals (C4), the heap cap (C1), recursion depth and `compile`/`exec`
  costs.

### F5. Stale or inconsistent docs — P2, S

| Doc | Problem |
| --- | --- |
| `synth/hammer/README.md:13,27` | "Nothing here has been run on the lab machines yet" contradicts the 18 ns post-route result. "`git checkout synth # until it is merged`" is stale. Lab paths are hard-coded in `genus_reports.tcl`, `area_by_reg.py` and `lec_dofile.py`; take them from an env var |
| `mpy_memory_map.md:47-48` | "Flash adds `MPY_FLASH_WAIT_STATES`" (B5) |
| `mpy_ca.md` (top) | "experimental bulk map engine": it is the default path |
| `mpy_peripherals.md` | Reads as integrated (C4) |
| `upycore_fpu.sv`, `upycore_fp_pow.sv` headers | Cite `docs/alu.md`, which does not exist. The FPU header describes CPython complex support |
| `mpy_bytecode.md:46` | "16-word frame header"; the RTL uses 17 (`mpy_core.sv:1342`) |
| `upycore/runtime/math.py:148` | Says `x ** 0.5` uses the power unit. The FPU sends `** 0.5` to the divider's correctly rounded sqrt (`S_POW_SQRT`). The result is the same; the comment is wrong |
| `timing_100mhz.md` / `timing_10ns.md` | Two overlapping timing docs (D5) |
| `.github/workflows/oracle-build.yml` | `mpy_translation` branch; a "goldens-fresh" job that does not exist (E4) |

### F6. Readability — P2, M (after the benchmark work)

- The newer RTL uses dense one-liners: several non-blocking assignments per
  line, no spaces, magic numbers. Examples:
  - `mpy_shortlist.sv` (whole file);
  - `mpy_map_engine.sv`, `mpy_bulk.sv`, `mpy_bytecopy.sv`;
  - `mpy_collection.sv`;
  - `mpy_core.sv:4032` (`mb_op_o<=7;mb_set_o<=1;...`).

  Reformat them to the style of `mpy_ca.sv`/`mpy_fetch.sv`, use named
  constants, and add a `verible-verilog-format` check.
- `mpy_core.sv` has grown to about 5,500 lines in one `always_ff` with
  about 470 states. Split it after B1–B3. The seams:
  - the front end;
  - the frame engine;
  - the lookup engine;
  - attributes;
  - numeric dispatch;
  - natives;
  - short-list control.
- Python tooling: add a `pyproject.toml` (Python ≥ 3.11), `ruff`, and one
  package instead of `sys.path.insert`.

---

## 3. Execution plan

| Wave | Items | Files |
| --- | --- | --- |
| 0 (independent of RTL) | E7, F1, F2, F3, F4, F5, E3, E5, A7 | Tests/goldens, docs, `hw_tests.py`, `variants/upycore/*` |
| 1 (firmware and tooling) | A1, A2, A3, A4 (firmware), A5, A6, E1, E4 | `upycore/firmware/{ops,floatfmt,builtins}.py`, `upycore/runtime/math.py`, `variants/upycore/build.sh`, `.github/workflows/*`, `upycore/programs/hw/alu/*` |
| 2 (small RTL) | B5, B11, D2, D3, C3, C4, B4 | `mpy_defs.svh`, `mpy_gc.sv`, `mpy_collection.sv`, `mpy_soc.sv`, `upycore_fpu.sv`, deletions, `mpy_core.sv` (`S_BIN`/`S_NUM`) |
| 3 (core structure) | B1, then B3, B2, B12, B9, A4/B7 natives, D4 | `mpy_core.sv`, `mpy_soc.sv`, `mpy_shortlist.sv`, `mpy_abi.py` |
| 4 (area) | E2, then C2, D1 | ALU/FPU files, `mpy_mem.sv` |
| 5 (sign-off) | E6, D5, C5, F6, B6, B8, B10 | Flow scripts, docs |

`mpy_core.sv` is the contention point: one PR per item, serialized.

For every PR:
- Run `make test-host`, `make test-unit`, and `hw_tests.py --area all`
  with both compilers. For RTL changes, also run with `+CA=0 +AALU=0`.
- For performance items, attach `clock_bench.py` or `timing_bench.py`
  output and `runtime_profile.py` reason shares.
- For timing items, attach the `timing_10ns.md` estimate-flow worst paths
  before and after.

---

## Appendix A. Reproduction

```bash
git submodule update --init --depth 1
make mpy-cross
python3 upycore/tools/mpy_build.py sim
variants/upycore/build.sh variant          # needs gcc-i686-linux-gnu and libc6-i386
python3 upycore/tools/mpy_build.py run probe.py
python3 upycore/tools/mpy_build.py oracle probe.py
```

The §A probe:

```python
def g(x): return x
print(abs(complex(g(1e10), g(0.0))), abs(g(1e5)+g(1e5)*1j), abs(complex(g(3e20), g(4e20))))
print(complex(g(1.0), g(2.0)) ** 2, g(-8.0) ** (1/3))
print(complex(g(1.5), g(2.5)) / complex(g(0.5), g(1.0)))
print(abs(g(-0.0)), abs(g(True)), round(g(16777217)), round(g(7), 2))
print(1/3, 1/3 == g(1.0)/g(3.0))
```

The SSE oracle:

```bash
cp -r build/oracle/src /tmp/oracle_sse && rm -rf /tmp/oracle_sse/ports/unix/build-upycore
make -C /tmp/oracle_sse/ports/unix VARIANT_DIR=$PWD/variants/upycore CROSS_COMPILE=i686-linux-gnu- \
  COPT="-Os -DNDEBUG -fdata-sections -ffunction-sections -msse2 -mfpmath=sse"
```

The profile:

```bash
cd upycore/tools && python3 runtime_profile.py --out ../../build/prof   # misc_aes, bm_fannkuch
```

The image-wait-state measurement: copy `upycore/rtl` and
`upycore/tb/{tb_mpy_soc,tb_spi_nand}.sv` to a scratch directory, set
`MPY_FLASH_WAIT_STATES = 0` in the copy's `mpy_defs.svh`, verilate with the
flags in `mpy_build.py build_sim`, and run
`timing_bench.py --before build/mpy_soc/obj/Vtb_mpy_soc --after <scratch>/Vtb_mpy_soc`.

The microbenchmark harness for §2.1 follows `timing_bench.py`. It is worth
adding as `upycore/tools/op_bench.py`. Run it from the repository root:
`python3 op_bench.py build/op_bench`.

```python
import sys
from pathlib import Path
sys.path.insert(0, 'upycore/tools')
import mpy_build as build
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
fw_src = out / 'bench_fw.py'; fw_mpy = out / 'bench_fw.mpy'
fw_src.write_text(build.firmware_source() + '\ndef bench_ticks():\n    return _ticks()\n')
build.mpy_cross(fw_src, fw_mpy, '_fw.py')
build.build_firmware = lambda: fw_mpy
N = 200
CASES = {
 'empty_loop': ('x', 'pass'),
 'load_store': ('x', 'y = x'),
 'int_add': ('x', 'y = x + x'),
 'int_mul_small': ('x', 'y = x * x'),
 'int_floordiv': ('x', 'y = x // 3'),
 'float_add': ('f', 'y = f + f'),
 'float_mul': ('f', 'y = f * f'),
 'float_div': ('f', 'y = f / 3.0'),
 'float_sqrt_pow05': ('f', 'y = f ** 0.5'),
 'float_abs': ('f', 'y = abs(f)'),
 'complex_add': ('z', 'y = z + z'),
 'complex_mul': ('z', 'y = z * z'),
 'complex_div': ('z', 'y = z / z'),
 'complex_abs': ('z', 'y = abs(z)'),
 'complex_pow2': ('z', 'y = z ** 2'),
 'list_index': ('L', 'y = L[1]'),
 'dict_get': ('D', 'y = D[1]'),
 'call_fn': ('x', 'y = g(x)'),
 'attr_method': ('L', 'y = L.count(1)'),
}
src_t = '''
def g(a):
    return a
def run(x, f, z, L, D):
    i = 0
    start = bench_ticks()
    while i < %d:
        %s
        i += 1
    return bench_ticks() - start
def base(x, f, z, L, D):
    i = 0
    start = bench_ticks()
    while i < %d:
        i += 1
    return bench_ticks() - start
b = base(7, 1.5, complex(1.5, 2.5), [1,2,3], {1:2})
t = run(7, 1.5, complex(1.5, 2.5), [1,2,3], {1:2})
print('BENCH', t, b)
'''
for name, (_, stmt) in CASES.items():
    work = out / name; work.mkdir(exist_ok=True)
    src = work / (name + '.py')
    src.write_text(src_t % (N, stmt, N))
    image = build.build_program(src, work, source_name=src.name)
    sim = build.run_image(image, max_cycles=200_000_000, timeout=900)
    lines = sim.stdout.decode().splitlines()
    m = [l for l in lines if l.startswith('BENCH')]
    if not m:
        print(name, 'FAILED', sim.halt, lines[-3:], sim.stderr.decode()[-300:]); continue
    t, b = map(int, m[0].split()[1:])
    print(f'{name:18} {(t - b) / N:10.1f} cycles/op   (loop {b / N:.1f})', flush=True)
```
