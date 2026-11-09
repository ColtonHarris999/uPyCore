# Planning

Plans for work that is **not done yet**, and the record of work in
progress. The machine as built is documented in `upycore/docs/`, and
`TESTING.md` describes the tests.

| File | Role |
| --- | --- |
| [`publish_readiness_review.md`](publish_readiness_review.md) | Full review of the design, firmware, tools, tests and docs, with prioritized items. Items already implemented are marked in its status table |
| [`runtime_optimization_plan.md`](runtime_optimization_plan.md), [`runtime_optimization_progress.md`](runtime_optimization_progress.md) | AES/Fannkuch runtime work: bytearray, slice, list pop/insert and strided-copy paths, with measurements |
| [`perf_bench_coverage_plan.md`](perf_bench_coverage_plan.md), [`perf_bench_coverage_progress.md`](perf_bench_coverage_progress.md) | Which MicroPython `perf_bench` programs run on the device. Steps 0–4 done; step 5 (VFS import) deferred |
| [`rv_io_core_plan.md`](rv_io_core_plan.md), [`rv_io_core_progress.md`](rv_io_core_progress.md) | Board I/O through an RV32 I/O core behind a bridge, with gates that keep the hart's cycles and timing unchanged. Being implemented phase by phase; the progress file has each phase's gate results |
| [`shortlist_engine_status.md`](shortlist_engine_status.md) | The short-list engine's validation and synthesis handoff |
| [`old/`](old/) | Archived and completed plans, including the CPython-to-MicroPython pivot plan, the GC, generator and uPy2-compiler plans, and the cleanup report. Code comments cite some of them by section, so they stay in the repo |

## Rules

- When a plan lands, move it to `old/`, add an `Archived` note at the top
  that points to the as-built doc, and copy anything still open into the
  review or a new plan.
- Do not duplicate opcode, type, or builtin tables here. Link to
  `upycore/targets/upycore.json` and the docs in `upycore/docs/`.
