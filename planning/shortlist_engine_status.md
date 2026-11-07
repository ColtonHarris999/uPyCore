# Short-list engine implementation checkpoint

Implementation and local validation are complete.
Timing baseline: `612df659f58c40f9889cac2877162a870b403550`; timing documentation
commit `211cbe349e31f2503412d401f2352e5d80407968` is incorporated. Pull request: https://github.com/ColtonHarris999/uPyCore/pull/57.

Implemented: native exact-list slice normalization/construction, shallow copy,
equal-length step-1 replacement, and pop/insert movement through an operation-local
16-element tagged snapshot engine; configurable 8-element option; ordinary heap
pointers; exclusive collection-port ownership and source/destination scoreboard
locks. All writes complete before return. No persistent dirty cache.

GC correction: clear obsolete inline items after native append or firmware reserve
grows a coallocated list into separate backing storage. The stress case now passes
all three modes and the accelerator-disabled configuration.

Validation: all 494 manifest cases covered under both compilers, including the
241-argument compiler rejection; 76 mpyc cases reuse a successful simulation
only after fresh compilation proves identical linked payload and tag images.
All 29 RTL benches pass (566 randomized short-engine cases), all 246 capacity/mode
micro runs pass, all 44 production-project runs match baseline output, and all
15 kernel callbacks match the captured baseline. Six new method-dispatch runs
cover all modes under both compilers. Saved evidence audit passes; see
upycore/docs/benchmarks/shortlist/validation.json and README.md.

Fannkuch cycles: baseline 34,391,764; native core 1,661,151; engine 1,557,009.
N-Queens: 152,359,283 / 115,947,120 / 115,909,110. Hexiom improves 3.68%; the
other 12 kernels change less than 0.003%. The 8-element engine matches both
Fannkuch and N-Queens, but the 16-element default accelerates more general lists.

Generic no-ABC core synthesis: 427,612 cells, 14,126 FF bits, zero latches;
baseline 419,657 / 13,692 / zero. Both core deepest paths remain 101 levels,
with the same FPU endpoints. Standalone 16/8 engines: 5,467/4,921 cells and
986/696 FF bits. Converted core/SoC and RTL stamp are refreshed. Physical
mapped/placed timing closure remains for the timing flow; 18 ns results are projected.

Known inherited issue: compiler_suite.py reports math_funcs.py mismatch. Identical
baseline source reproduces identical compiler outputs and mismatch. Final host
comparison: 504 files, 500 byte-exact, three float spelling differences, one inherited
mismatch. No fresh pinned 32-bit Unix oracle run is available; new common-subset
expected outputs use CPython. Do not claim that inherited mismatch was fixed.
