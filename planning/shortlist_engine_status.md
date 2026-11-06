# Short-list engine implementation checkpoint

Work is isolated on `codex/short-list-engine`, based on pushed timing commit
`612df659f58c40f9889cac2877162a870b403550`. Do not reset or update `benchmark`,
`main` or `synth`; another agent owns timing work.

Implemented: exact short-list +/-1 slice get, shallow copy, equal-length
step-1 replacement, pop/insert routing, native normalization and contiguous
BUILD_LIST-compatible construction; operation-local 16-element tagged buffer,
8-element option, exclusive collection port and source/destination locks.
`+SL=0/1/2` selects legacy/native-core/engine; `+CA=0` uses core movement.
No persistent writeback cache or new Python value representation.

Validation completed on the prototype: all 29 RTL unit benches; 566 new
randomized unit cases across 8/16 capacities including stalls, faults and
response backpressure; collection ownership ordering; 204 matched-image
microbenchmark runs; all 15 upstream kernel callbacks match the fresh
612df65 baseline. Fannkuch 34,391,764 -> 1,557,006 cycles; N-Queens
152,359,283 -> 115,914,724. These are provisional, before the GC fix below.

A stress regression caught obsolete inline item references after growth.
The old engine path exhausts memory keeping 80 grown list headers alive;
legacy short-list mode passes. The current working code clears old inline
slots after copy in both native append and firmware reserve. This is required
for using contiguous constructors safely. The test is
`hw/gc/shortlist_grow_roots.py`. Verify all three modes before final runs.
The two earlier full hardware runs were deliberately stopped after this
fix; their partial PASS logs must not be reported as full final passes.

Synthesis prototype: no-ABC generic core deepest endpoint remains 101 levels
(same baseline critical paths); unit depth 44. Production synthesis omits
the comparison-only core snapshot buffer. Regenerate core/SoC converted
Verilog and RTL_STAMP again after the GC fix, and refresh PPA data.
No physical timing closure claim is justified by generic depth alone.

Known inherited issue: compiler_suite.py differs on math_funcs.py. Recompiled
that identical source from 612df65 and obtained the identical pair of compiler
hashes/mismatch. Neither compiler nor that source was changed here. Do not
hide it, mark it fixed, or alter the compiler as part of this optimization.

Next: finish GC stress validation; freeze code; run full hardware suite with
mpy-cross and mpyc, final 15-kernel baseline comparison, core/engine Fannkuch
comparison, production project suite four modes, micro curves and 8-element
regressions. Update docs with final evidence and upload only this branch.
Create a draft PR targeting benchmark; do not merge into the timing agent's
branches. Keep exact source/image/simulator hashes and report limitations.
