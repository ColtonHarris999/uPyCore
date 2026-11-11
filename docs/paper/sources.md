# Sources for the board comparison

Every board time in [`benchmark-board-ms.csv`](benchmark-board-ms.csv), where
it comes from, and how far it was checked (November 2026). All of them are
MicroPython's own `tests/run-perfbench.py` on the `tests/perf_bench` kernels,
the same programs µPyCore runs.

## How a published number becomes a milliseconds cell

`run-perfbench.py` prints, per kernel, `time_us time_sd% score score_sd%`,
where `time_us` is one `run()` and `score = 1e6 * norm / time_us`; `norm` is
the first element of the kernel's `result()`. A source that gives the time is
used as `time_us / 1000`. A source that gives only scores (`-s`, "diff of
scores") is converted with `ms = 1000 * norm / score`, using these `norm`
values (from each kernel's `result()` at the selected parameters):

| Kernel | norm | Kernel | norm |
| --- | ---: | --- | ---: |
| bm_chaos | 50 | core_qstr | 4 |
| bm_fannkuch | 6 | core_str | 6 |
| bm_fft | 768 | core_yield_from | 20 |
| bm_float | 250 | misc_aes | 32 |
| bm_hexiom | 10 | misc_mandel | 400 |
| bm_nqueens | 1000 | misc_pystone | 300 |
| bm_pidigits | 65 | misc_raytrace | 50 |
| bm_wordcount | 8 | core_locals | 8 |

The sources use N=100 M=100 or N=160 M=100. For every kernel in the table
both pick the same parameter set (checked against each kernel's `bm_params`:
the harness takes the largest `(n, m)` with `10 n <= 12 N` and `m <= M`), so
they time the same work as µPyCore's N=100 M=100 runs.

## Columns

### Pyboard v1.0 (STM32F405, 168 MHz nominal): verified, exact

- Source: MicroPython PR #18571, "py: Add a new dual-VM option to improve
  performance of `sys.settrace`", Damien George, opened 15 Dec 2025.
  <https://github.com/micropython/micropython/pull/18571>
- Run: `perf-pyb-std` (standard VM, settrace off), N=100 M=100, scores.
  The PR gives no MicroPython commit for the baseline (it targets master,
  December 2025) and no clock.
- Published baseline scores: bm_chaos 356.93, bm_fannkuch 72.90, bm_fft
  2331.03, bm_float 5713.01, bm_hexiom 45.75, bm_nqueens 4111.33,
  bm_pidigits 663.16, bm_wordcount 47.36, core_locals 40.28, core_qstr
  204.36, core_str 25.86, core_yield_from 355.61, misc_aes 407.85,
  misc_mandel 3166.90, misc_pystone 2378.74, misc_raytrace 361.02.
- Check: every one of the 16 CSV cells equals `1000 * norm / score` to the
  0.1 ms shown.

### PyBD SF6 (STM32F767, 216 MHz nominal): verified, exact; replaces Pyboard v1.1

- Source: MicroPython PR #7688, "py/vm.c: Add a fast path for LOAD_ATTR on
  instance types.", Jim Mussared, 19 Aug 2021
  (<https://github.com/micropython/micropython/pull/7688>); the same
  baseline run (`~/cache-baseline-sf6`) is also the left-hand side of the
  three PYBD_SF6 tables in PR #7680 (18 Aug 2021,
  <https://github.com/micropython/micropython/pull/7680>).
- Run: `./run-perfbench.py -s ~/cache-baseline-sf6 ...`, N=100 M=100, scores.
  No commit (August 2021 master) and no clock given.
- Published baseline scores: bm_chaos 382.55, bm_fannkuch 101.40, bm_fft
  1815.18, bm_float 5939.99, bm_hexiom 49.78, bm_nqueens 5706.74,
  bm_pidigits 959.77, misc_aes 530.32, misc_mandel 4037.38, misc_pystone
  2485.09, misc_raytrace 401.04. The run predates bm_wordcount,
  core_locals, core_qstr, core_str and core_yield_from in perf_bench, so
  those cells are empty (11 kernels).
- The CSV cells are `1000 * norm / score` with today's `norm`. That
  assumes those 11 kernels' parameters and `result()` are unchanged since
  August 2021 (not checked against the 2021 source).
- No newer PYBD table was found: PRs #16015, #19128, #19771 and #8733
  mention PYBD boards but publish no PYBD numbers.
- Caveat: August 2021 firmware, the oldest in the table. `bm_fft` (423.1 ms)
  is slower than on Pyboard v1.0 (329.5 ms) although the F767 is the faster
  MCU; PYBD builds use double-precision floats (my understanding of the
  board config, not stated in the PR), and the run is four years older.

The Pyboard v1.1 column (PR #10758, February 2023) was dropped: same MCU as
Pyboard v1.0 on older firmware, and its `core_qstr` predates MicroPython's
faster qstr lookup.

### ESP32-C3 (160 MHz): verified, exact; source citation corrected

- Source: MicroPython discussion #10516, "WeAct Studio ESP32-C3FH4 Mini Core
  Board: works as expected", Stewart Russell (`scruss`), 17 Jan 2023.
  <https://github.com/micropython/micropython/discussions/10516>
- Run: `./run-perfbench.py -p -d /dev/ttyACM1 160 100`
  (`N=160 M=100 n_average=8`), port `GENERIC_C3_USB` (version not stated,
  January 2023), CPU 160 MHz. Rows give `time_us`, so no conversion factor
  is involved.
- Published times (µs): bm_chaos 136847.75, bm_fannkuch 62070.75, bm_fft
  311446.50, bm_float 63105.50, bm_hexiom 194644.62, bm_nqueens 210511.00,
  bm_pidigits 74477.50, core_qstr 32988.00, core_yield_from 74422.25,
  misc_aes 63978.75, misc_mandel 153923.00, misc_pystone 128676.88,
  misc_raytrace 122708.62. No bm_wordcount, core_locals or core_str.
- Check: all 13 CSV cells match (bm_fft 311.4 ms and bm_pidigits 74.5 ms
  were added from this source in November 2026; the other 11 were already
  there).
- The paper README cited a ChatGPT library link for these numbers; that is
  not a public source. The citation is now this discussion.

### Pico RP2040, Pico 2 Arm, Pico 2 RISC-V: not verified

- Cited sources: Raspberry Pi forum posts
  <https://forums.raspberrypi.com/viewtopic.php?p=2259682> (Pico) and
  <https://forums.raspberrypi.com/viewtopic.php?p=2267212> (Pico 2, Arm and
  RISC-V cores); the thread appears to be "Benchmark Pico 2"
  (<https://forums.raspberrypi.com/viewtopic.php?t=377831>).
- The forum serves a Cloudflare browser check to automated clients, so the
  posts could not be read from this environment. The author, date,
  firmware, clock and raw numbers still have to be copied from the posts by
  hand. Until then these three columns are unverified.
- Independent cross-check for the RP2040 only: PR #10758 (above) also has
  an RP2040 baseline run (`qstr-no-hash-rp2-baseline`, N=100 M=100,
  February 2023 master, clock not stated; scores: bm_chaos 212.85,
  bm_fannkuch 51.73, bm_fft 1400.41, bm_float 3757.68, bm_hexiom 27.58,
  bm_nqueens 2681.04, bm_pidigits 398.56, core_qstr 52.20, core_yield_from
  217.72, misc_aes 283.68, misc_mandel 1599.78, misc_pystone 1443.18,
  misc_raytrace 227.18). Converted, against the CSV:

| Kernel | PR #10758 (ms) | CSV (forum, ms) | CSV vs PR |
| --- | ---: | ---: | ---: |
| bm_chaos | 234.9 | 223.7 | −5 % |
| bm_fannkuch | 116.0 | 106.4 | −8 % |
| bm_fft | 548.4 | — | |
| bm_float | 66.5 | 102.0 | **+53 %** |
| bm_hexiom | 362.6 | 283.4 | −22 % |
| bm_nqueens | 373.0 | 433.8 | +16 % |
| bm_pidigits | 163.1 | — | |
| core_qstr | 76.6 | 29.2 | −62 % (qstr speedup after 2023) |
| core_yield_from | 91.9 | 109.8 | +20 % |
| misc_aes | 112.8 | 103.2 | −9 % |
| misc_mandel | 250.0 | 231.3 | −7 % |
| misc_pystone | 207.9 | 211.6 | +2 % |
| misc_raytrace | 220.1 | 206.5 | −6 % |

  Most kernels agree within about 10 %, as expected across firmware
  versions. `bm_float` is 53 % slower in the CSV than in the 2023 run, and
  `core_yield_from` and `bm_nqueens` 16–20 % slower; these should be checked
  against the forum post first.

## Other things to state in the paper

- The board runs are from different MicroPython versions: August 2021 (PyBD SF6), January 2023
  (ESP32-C3), probably 2024–2025 (Pico
  forum posts, to be confirmed), December 2025 (Pyboard v1.0). µPyCore
  matches MicroPython v1.29.0.
- None of the sources states the clock it ran at except the ESP32-C3
  post (160 MHz). The per-clock comparison uses each board's stock
  MicroPython clock (RP2040 125 MHz, RP2350 150 MHz, STM32F405 168 MHz, STM32F767 216 MHz);
  that is an assumption.
- `core_qstr` does different work on µPyCore (see
  `upycore/docs/known_limitations.md` and the README note).
