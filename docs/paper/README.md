# Paper / systems documentation

Near-complete PyCore subsystems get a LaTeX note here so we can pull prose,
figures, and tradeoff tables into the research paper without mining RTL comments
or planning markdown.

## Layout

| Path | Topic |
| --- | --- |
| `systems/call_fsm.tex` | `S_CALL` FSM, shared argument binder, CPython call shapes |

## Build

```bash
cd docs/paper/systems
pdflatex call_fsm.tex
pdflatex call_fsm.tex   # TOC
```

Needs a TeX distribution with `tikz`, `booktabs`, `hyperref`, `listings`,
`geometry`, `microtype`.

## Conventions

- One subsystem per `.tex` file under `systems/` (or a future `excore/`, etc.).
- Prefer diagrams that match RTL names (`call_phase_r`, binder subs) so the note
  stays a faithful companion to the code.
- Link the living opcode matrix (`pycore/docs/bytecode_support.md`) rather than
  duplicating support status that churns weekly.
- Remaining work lives in `planning/README.md` (open plans), not in these notes.

## Benchmark comparison figures

Run from the repository root with the pinned submodules, Verilator, and
Matplotlib installed. Set the projection period from the timing analysis for
the design being reported. For example, the mapped Sky130 HD TT estimate for
the core RTL in `676d273` was 11.775 ns.

```bash
make mpy-cross sim
python3 upycore/tools/shortlist_bench.py \
  --out build/paper-shortlist \
  --compare upycore/docs/benchmarks/shortlist/kernels.json
python3 upycore/tools/perf_inventory.py \
  --only bm_pidigits --points 100x100 --bigint --out build/paper-pidigits
python3 upycore/tools/paper_benchmark_plot.py build/paper-shortlist/results.json \
  --pidigits build/paper-pidigits/results.json --clock-ns 11.775 \
  --out-dir build/paper-figures
```

The commands measure the benchmark run callable with CA and AALU enabled at
N=100, M=100. Use `make oracle-mpz` to check Pi digits against the pinned
MicroPython MPZ oracle. The inventory runner uses CPython for Pi digits when
the MPZ oracle is unavailable. The shortlist comparison checks source and
harness identity and result callbacks, whose correctness coverage varies by
kernel.

The script writes vector PDFs and 300 dpi PNGs. Pystone reports throughput for
300 iterations. The suite plots the remaining kernels on a log runtime axis
with markers only where timings exist. The average is the geometric mean of
`Pico RP2040 runtime / device runtime` across non-Pystone kernels with timings
for every plotted device. With the supplied table those are Chaos, Fannkuch,
N-Queens, Interned strings, and Generator delegation. The script prints the
selected kernels and per-device scores.

[benchmark-board-ms.csv](benchmark-board-ms.csv) carries forward the published
board comparison at the precision recorded in the prior benchmark reports.
Empty cells indicate unavailable matched timings. The Pyboard columns use the
baseline scores from the cited comparisons converted to milliseconds using
each workload's normalization count. Firmware versions and measurement
conditions vary across sources. µPyCore time is RTL cycles multiplied by the
supplied clock period. State the timing model in the paper caption and identify
the µPyCore values as projected.

- [Original Pico measurements](https://forums.raspberrypi.com/viewtopic.php?p=2259682)
- [Stock Pico 2 Arm and RISC-V measurements](https://forums.raspberrypi.com/viewtopic.php?p=2267212)
- [Pyboard v1.0 standard VM measurements](https://github.com/micropython/micropython/pull/18571)
- [Pyboard v1.1 baseline measurements](https://github.com/micropython/micropython/pull/10758)
- [Prior comparison including the ESP32-C3 runtimes](https://chatgpt.com/library?file_id=libfile_946bed05b36c8191a4d14b1eebd4c29b&account_id=personal)
