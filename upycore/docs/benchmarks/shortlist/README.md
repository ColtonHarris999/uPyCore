# Short-list evaluation evidence

Baseline: `612df659f58c40f9889cac2877162a870b403550`; timing documentation
update `211cbe349e31f2503412d401f2352e5d80407968` changes no RTL. See
[the report](../../shortlist_engine.md) for interpretation and limitations.

| Files | Contents |
| --- | --- |
| `baseline-kernels.json`, `kernels.json` | All 15 kernels, N=100/M=100, run-body cycle boundary, assumed 18 ns |
| `native-core-kernels.json`, `eight-kernels.json` | Matched-image Fannkuch/N-Queens comparisons |
| `baseline-project.json`, `project.json` | Eleven production images in four CA/AALU modes; startup included |
| `micro.json`, `eight-micro.json` | 204 default-build and 42 8-element matched-image runs; loop/call overhead included |
| `method-cases.json` | Copy dispatch, arity/type errors, overrides, and boolean indices in all modes under both compilers |
| `image-equivalence.json` | Source and linked payload/tag hashes for reuse of identical compiler outputs |
| `gc-mode*.json`, `no-ca-*.log` | Inline-growth retention and accelerator-disabled coverage |
| `ppa.json`, `*-depth.txt`, `*-synth.ys` | Generic no-ABC resource/depth comparison and scripts; no physical timing claim |
| `environment.json` | Toolchain hashes, vendor pins and RTL stamp |
| `unit-tests.log` | Final 29 RTL benches, including 566 short-engine cases |
| `host-models.log`, `manifest-tests.log` | Host models and manifest checks |
| `compiler-suite.log` | Final 504-file comparison; one inherited mismatch |
| `host.log`, `inherited-compiler-check.log` | Earlier host capture before the last test was added, and baseline mismatch reproduction |
| `latency.svg`, `latency.png` | Plots generated directly from `micro.json` |
| `validation.json` | Completed-coverage audit and hashes of this evidence |

Hardware coverage is joined by `area/name` from `hardware-initial.log` and
`hardware-resumed.log`, and similarly for `mpyc`. The initial post-fix captures
passed 355 tests each, encountered two wall-clock timeouts under CPU contention,
then stopped when an external compiler path disappeared. The remaining 138
tests were restarted with identical, locally isolated compiler/simulator
binaries, a 2400-second wall-time floor, and unchanged cycle budgets. That
capture was interrupted after another 38 passes per compiler. The supplemental
hardware capture covers the remaining 100 tests with the same simulator and
cycle budgets. Freshly compiling those 100 programs with `mpyc` produces
byte-identical linked payload and tag images, recorded in `image-equivalence.json`.
The audit reuses the corresponding passing hardware run for those identical
images; it does not claim a second independent simulation. The redundant second
capture records additional passing cases before cancellation; only missing
identical images reuse the first run. The newly
added method regression is covered separately by `method-cases.json`.

The `*-invalid-runner.log` captures preserve a temporary launcher failure before
cycle zero. These attempts were superseded in full and contribute no coverage.
Historical failures remain visible; only a later passing rerun can supersede
one in the coverage audit. A `*-supplement.log`, when present, records an
additional rerun with its stated wall-time allowance and unchanged cycle budget.

Run `python3 upycore/tools/shortlist_validate.py` from the repository root to
audit the saved captures against the current manifest, RTL and firmware.
Missing cases or failed final results are errors. The audit is a consistency
check, not an independent oracle: existing goldens are retained, the three new
regressions use common-subset CPython expected outputs, and no fresh pinned
32-bit Unix oracle or physical timing run was available.
