# perf_bench on uPyCore

uPyCore runs MicroPython v1.29.0 bytecode. The benchmark is that tree's
`tests/perf_bench`, compiled offline and timed from the hart's cycle counter.
Score per MHz is `1e6 * norm / cycles`. The simulator produces that figure
directly: `time.ticks_us` returns cycles, so the number `benchrun.py` prints
is already the denominator.

The pin is `vendor/micropython` at v1.29.0 (`0fd6c573`). Parameter keys below
were read from that tree, not from a later `master`.

## Which programs

The directory has 24 benchmark scripts plus `benchrun.py`. Six `viper_*`
files call `@micropython.viper` and `@micropython.native`. `run-perfbench.py`
skips them when the native-emitter probe fails, and this hart has no native
emitter. `core_import_mpy_single` and `core_import_mpy_multi` mount a RAM VFS
and load a hand-built `.mpy`; they measure the loader, and this image has no
VFS. That leaves 16 bytecode programs.

`benchrun.py` keeps the largest `(N, M)` key with `10 * N' <= 12 * N` and
`M' <= M`. The smallest integer `N` that selects a key is `ceil(10 * N' / 12)`:
27 for a key of 32, 42 for 50, and 84 for 100. The `M` in the key is the
authors' minimum, not a measured high-water mark. This hart's GC pool is
228,096 bytes. Every passing run below collected zero times, so the live set
fit in that pool. Peak heap was not sampled.

| Program | Tier | Smallest key | Workload at that key | Needs |
| --- | --- | --- | --- | --- |
| `misc_pystone` | A | (50, 10) | 80 loops | int |
| `misc_aes` | A | (50, 25) | 1 loop, 16-byte buffer | int |
| `bm_fannkuch` | A | (32, 10) | n = 3 | int |
| `bm_nqueens` | A | (32, 10) | 1 × 5 queens | generators |
| `bm_wordcount` | A | (32, 10) | niter = 2 | int |
| `core_locals` | A | (32, 10) | niter = 2 | int, 141 state slots |
| `core_str` | A | (32, 10) | niter = 2 | int |
| `core_qstr` | A | (32, 10) | 400 loops, norm 4 | int |
| `core_yield_from` | A | (100, 10) | 2000 yields, depth 10 | generators |
| `bm_pidigits` | A | (32, 10) | 20 digits | arbitrary-precision int |
| `bm_float` | B | (50, 25) | (1, 150) | float, `math` |
| `bm_fft` | B | (50, 25) | (2, 128) | complex, `cmath` |
| `bm_chaos` | B | (100, 50) | pixel percent | float, `math`, `random` |
| `misc_mandel` | B | (100, 100) | 20 × 20 | complex; result is `None` |
| `misc_raytrace` | B | (100, 100) | 5 × 5 × 2 | float; result is `None` |
| `bm_hexiom` | C | (100, 100) | level 10 | `io.StringIO` |

Tier A is the integer set. Nine of those names, plus `bm_fft`, are the ten
programs in Figure 6 of Lowther, Jacob, Trevor, and Singer, "Secure Scripting
with CHERIoT MicroPython", CC '25. That paper reports a geometric-mean
overhead of 48% on a CHERIoT-Ibex (RV32EMCB) soft core clocked at 30 MHz,
with the interpreter built for a 64 KiB heap. `bm_fft` waits until a complex
run is worth timing. `bm_nqueens` and `core_yield_from` run; both matched
CPython after generator support landed.

Scores are comparable only at the same `bm_params` entry. `norm` is only
roughly the work. `bm_fannkuch` sets `norm = n` while the permutation work
grows factorially, and `bm_wordcount` is quadratic in its parameter. An RTL
score at n = 3 is not a speedup over a published n = 6 score.

## How a run is built

`upycore/tools/perfbench.py` follows `tests/run-perfbench.py`:

1. Concatenate `import sys` / `sys.path.remove('')`, the benchmark,
   `benchrun.py`, and `bm_run(N, M)`. The device `sys.path` starts with `''`
   so that removal succeeds. Import does not consult the list.
2. Compile with `mpy-cross -msmall-int-bits=31 -O0 -X emit=bytecode`.
3. Link the `.mpy` into the flash image. Bytecode executes from flash.
4. `time.ticks_us` and `time.ticks_cpu` return `cyc[29:0]`. `ticks_diff` and
   `ticks_add` use the `2**30` period from MicroPython's utime helpers.
   `benchrun.py` imports those two names and prints
   `<elapsed> <norm> <result>`.
5. Score per MHz = `1e6 * norm / elapsed`.
6. Compare `norm` and `result` with CPython running the same bytes on stdin.
   A result of `None` is not a failure, which is what `run-perfbench.py` does
   (`core_qstr`, `misc_mandel`, `misc_raytrace`).

The memory model in `upycore/rtl/mpy_defs.svh` is SRAM latency 1 and one
flash wait state. The counter is the hart's cycle counter, so both are inside
the score. A run from reset is deterministic. A second run of `misc_pystone`
and `bm_fannkuch` reproduced the cycle counts below exactly, so the tables
are one shot each.

`tests/internal_bench` is the per-construct suite: 86 files in 11 families
(`arrayop` 4, `bytealloc` 2, `bytebuf` 3, `class_create` 18, `class_instance`
13, `from_iter` 8, `func_args` 5, `func_builtin` 2, `funcall` 3, `loop_count`
6, `var` 22), plus `bench.py`. `perfbench.py internal` injects the same
`ticks_us` harness `run-internalbench.py` uses on a board and prints cycles.
Files that divide the iteration count by 10,000 are raised to at least 10,000
iterations so the loop body runs.

## Tier A on the simulator

Smallest qualifying `(N, M)` for each file. `cycles` is the timed `run()`,
not the halt-line total. Untimed cycles (boot, `bm_setup`, printing the
result) are `sim_cycles - cycles`.

| Program | (N, M) | Workload | Status | Cycles | norm | per MHz | Check |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `misc_pystone` | (42, 10) | 80 loops | pass | 3,642,863 | 80 | 21.961 | result `0` |
| `misc_aes` | (42, 25) | (1, 16) | pass | 29,658,190 | 16 | 0.5395 | result `True` |
| `bm_fannkuch` | (27, 10) | n = 3 | pass | 183,587 | 3 | 16.341 | result `2` |
| `bm_wordcount` | (27, 10) | niter = 2 | pass | 1,614,874 | 2 | 1.2385 | `(2, 20, 16)` |
| `core_str` | (27, 10) | niter = 2 | pass | 13,189,246 | 2 | 0.1516 | matches CPython |
| `core_qstr` | (27, 10) | 400 loops | pass | 703,103 | 4 | 5.689 | result `None` |
| `bm_nqueens` | (27, 10) | 5 queens | pass | 28,994,791 | 100 | 3.449 | result `10` |
| `bm_nqueens` | (100, 100) | 6 queens | pass | 189,937,870 | 1000 | 5.265 | result `4` |
| `core_yield_from` | (84, 10) | 2000 | pass | 36,732,891 | 20 | 0.5445 | `1999000` |
| `bm_pidigits` | (27, 10) | 20 digits | skip |  |  |  | script prints `SKIP` |
| `core_locals` | (27, 10) | niter = 2 | does not link |  |  |  | 141 state slots, frame holds 64 |

`bm_pidigits` tries `int("0x10000000000000000", 16)` and skips when that
overflows. The unix oracle is `LONGLONG` and the hart raises `OverflowError`
past 64-bit ints, so both skip. CPython computes the 20 digits
`31415926535897932384`. The skip itself finished in 53,381 cycles.

`core_locals` builds one module-level list of the words it will use as
attribute names. That list literal needs 141 state slots. `mpy_link.py`
rejects a function whose prelude `n_state` exceeds the 64-entry register
file. The CPython result at this workload is `(2, 20, 16)`.

On `misc_pystone` the halt line reported 5,364,179 cycles and 210,945
bytecode dispatches. The timed region is 3,642,863 of those cycles. The
score uses the timed region. Setup of `bm_fannkuch` at n = 3 costs more
cycles (211,974 untimed) than the timed permutation (183,587).

### Where a published table is the same workload

Published perfbench tables used below are the "this commit" column at
`N=100 M=100`:

- PYBv1.0, commit `f2040bfc7`. The message does not state the clock. 168 MHz
  is the board's usual clock. Per-MHz figures that use 168 are derived.
- RP2040, commit `79edaddf5`. The message does not state the clock. 125 MHz
  is the chip's default. Per-MHz figures that use 125 are derived.
- ESP32 TinyPICO, commit `549448e8b`, which says the board was running at
  160 MHz.

`core_qstr`'s next key after `(32, 10)` is `(1000, 10)`, which needs
`N >= 834`. An `N=100` run therefore still executes 400 loops with norm 4.
Cycles for that run are `1e6 * 4 * MHz / score`:

| Source | Score | Assumed MHz | Cycles | per MHz |
| --- | --- | --- | --- | --- |
| uPyCore, this image |  |  | 703,103 | 5.689 |
| RP2040 `79edaddf5` | 140.84 | 125 | 3,550,128 | 1.127 |
| PYBv1.0 `f2040bfc7` | 64.12 | 168 | 10,480,349 | 0.382 |

Against those assumptions the hart used about 5.0× fewer cycles than the
RP2040 figure and about 14.9× fewer than the PYBv1.0 figure. The clocks are
not in the commit messages, so the ratios move if the boards were not at
those clocks.

`misc_pystone` sets `norm` to the loop count and times `Proc0(loops)`.
Cycles per loop do not depend on whether the table ran 300 loops (`N=100`)
or this run's 80. This image took 45,536 cycles per loop (21.96 per MHz).
Derived the same way: about 69,800 cycles/loop on the PYBv1.0 figure
(14.32 per MHz at 168), about 85,800 on the RP2040 figure (11.65 per MHz
at 125), and 88,797 on the ESP32 figure (11.26 per MHz at the stated 160).
That is about 1.5×, 1.9×, and 2.0× fewer cycles per loop than those three
interpreter scores. The ESP32 commit warns that external flash and caching
make that port hard to measure. This image's flash has a fixed one-wait
fetch, which is a different memory system than those boards.

`core_str` is also linear: `norm` is `niter` and the body is one pass per
`niter`. This run (niter 2) scored 0.152 per MHz. The RP2040 table's `N=100`
key is niter 6 and scored 18.10, which is 0.145 per MHz at an assumed 125.
The two are close. String split, join, replace, `ord`, and `chr` are
firmware on this hart, so a bytecode datapath does not show up the way it
does on `core_qstr`.

`core_yield_from` at this `(N, M)` is the `N=100` workload: 2000 steps through
a 10-deep `yield from`, norm 20, result `1999000`. This image took 36,732,891
cycles (0.544 per MHz). Derived the same way, the PYBv1.0 score 354.50 is
about 9.48 million cycles at 168 MHz (2.11 per MHz) and the RP2040 score
211.72 is about 11.8 million cycles at 125 MHz (1.69 per MHz). The hart used
about 3.9× and 3.1× more cycles than those two figures.

`bm_nqueens` at `N=100 M=100` is one search of 6 queens, norm 1000, result
`4` (the 5-queen run above is the smaller key, result `10`). This image took
189,937,870 cycles (5.26 per MHz). Derived: about 37.7 million cycles on the
PYBv1.0 figure (4459.94 at 168 MHz), 55.3 million on the RP2040 figure
(2259.78 at 125 MHz), and 67.4 million on the ESP32 figure (2372.87 at 160
MHz). The hart used about 5.0×, 3.4×, and 2.8× more cycles than those three.

Across the five RP2040 comparisons whose work matches (`core_qstr` 5.0×,
pystone 1.9×, `core_str` 1.0×, `core_yield_from` 0.32×, `bm_nqueens` 0.29×)
the geometric mean is 0.99×. The largest single figure is still `core_qstr`
at 5.0× versus that board, or 15× versus the PYBv1.0 figure.

These passing scores are a different workload from the `N=100` tables:

- `bm_fannkuch` here is n = 3 (result 2). The `N=100` key is n = 6. The
  score of 16.3 per MHz against a published ~0.46 per MHz is the factorial
  work against a linear norm, not a speedup.
- `bm_wordcount` here is niter 2. The `N=100` key is niter 8, and the inner
  loops are quadratic in niter.
- `misc_aes` here is one loop of 16 bytes (norm 16, 0.5395 per MHz, result
  `True`). The `N=100` key is one loop of 32 bytes. Key setup is paid once
  per loop either way, so the scores are not the same workload.

## internal_bench, loop_count, 1,000 iterations

Cycles are the timed call only. Per-iteration is that total divided by 1,000.

| File | Cycles | Per iteration |
| --- | --- | --- |
| `loop_count-1-range` | 43,654 | 43.65 |
| `loop_count-2-range_iter` | 51,303 | 51.30 |
| `loop_count-3-while_up` | 43,635 | 43.64 |
| `loop_count-4-while_down_gt` | 43,627 | 43.63 |
| `loop_count-5-while_down_ne` | 43,627 | 43.63 |
| `loop_count-5.1-while_down_ne_localvar` | 43,635 | 43.64 |

`for i in range(n)` and the three `while` shapes land within 8 cycles of
each other across 1,000 iterations. The iterator form
(`for i in iter(range(n))`) costs 7,649 cycles more, 7.65 per iteration.
Subtracting a pair is the overhead-loop method JemBench uses for a single
bytecode. The other ten families are the same command with a different
family name.

## Run

```bash
python3 upycore/tools/perfbench.py list
python3 upycore/tools/perfbench.py truth          # CPython norm and result
python3 upycore/tools/perfbench.py run            # tier A, smallest (N, M)
python3 upycore/tools/perfbench.py run --n 100 --m 100
python3 upycore/tools/perfbench.py internal loop_count --iters 1000
make bench
```

`make bench` is not part of `make test`. Tier B and tier C are not in the
default run. A truth mismatch, a timeout, or a tick wrap exits nonzero.
`core_locals` still fails to link (141 state slots). `bm_pidigits` still
prints `SKIP`.
