# uPyCore suite acceleration — recovery checkpoint

Benchmark sources and harness must remain unchanged. Optimize compiler, firmware and hardware only. Evaluate time as cycles × 12 ns (83.33 MHz); clock achievement requires physical timing signoff. Preserve the complete historical capture and per-test target budgets alongside this plan.

## Current recoverable implementation

Base: f15327a. Branch: codex/suite-recovery. Firmware changes: unit-stride string/bytes/bytearray slicing uses existing _bcopy instead of a per-byte firmware loop; _fsqrt uses existing scalar POW(0.5) instead of 12 Newton iterations, preserving negative-input and zero guards. No RTL or benchmark edits.

## Recovery limitation

Two continuation events restored an older workspace. Earlier acceleration commits 378cec8, e62c96d, aac2429 and 7542fa8 are absent from the current object database, and the acceleration branch is absent from the fetched remote. Earlier raw profiles and test logs are also absent. Treat their numbers as prior observed results from the conversation, not reproducible evidence for this recovered branch. Remote publication had been rejected by automatic approval review, requiring explicit permission to disclose new contents to the public repository.

## Plan ordered by measured bottlenecks

1. Preserve a remote checkpoint before further long runs; retain source, compiler, simulator, firmware and harness hashes with every capture. Profile exclusive cycles and aggregate duplicate function display names rather than overwriting them. Validate return values independently where possible.
2. Strings: finish bulk-slice validation; restore native ASCII chr/ord and word-cached string hashing. Keep Unicode, error and conversion semantics. Then profile substring search. Reuse shared memory datapaths.
3. Instance attributes: restore exact-instance QSTR hit lookup and public getattr/setattr paths; guard descriptor/custom-setter flags, fall back on misses/special names, avoid caches without invalidation. Restore inherited scalar descriptor guard regression fix.
4. Wordcount: restore native exact dict.get and shared scalar map insertion; test custom hashing/equality, collisions, tombstones, growth, allocation failures and GC. Never replay user callbacks after a partial operation.
5. Mandelbrot: restore native complex +,-,* and abs using the shared scalar ALU with binary32 rounding matching firmware operation order. Reuse rooted scratch state and existing FPU; no duplicated arithmetic units.
6. Hexiom: restore primitive list/tuple equality and membership with callback-safe fallback and native type predicates. Profile remaining dispatch before choosing broader changes.
7. N-Queens: after map/predicate paths, target iterator construction, reversed ranges, generator resume/frame transfer, tuple materialization and list operations. Changes must be generic; no benchmark recognition or rewritten algorithm.
8. Yield-from: profile resume and frame-spill costs; validate send/throw/close, StopIteration values, nested delegation and GC before changing frame handling.
9. Float/Chaos/raytrace/Pystone: numeric constructor conversion and range-reduction helpers; preserve rebinding and errors. Keep AES/fannkuch/qstr results as regression controls.

## Acceptance

Run all unchanged kernels with identical N=100/M=100 and accelerator flags, check every callback and source hash. Report both 18ns and12ns projections. Every comparable row must meet its own budget; geometric means do not establish competitiveness. Run targeted semantic, full hardware/unit, uPy2 compiler, accelerator-disabled and GC/oom checks. Explain inherited failures rather than regenerating goldens. Compare identical synthesis constraints, flop/cell counts and critical paths; generic synthesis is not physical area or routed timing. Require activity-based evidence for power claims. Do not merge this partial recovery as the completed suite acceleration.
