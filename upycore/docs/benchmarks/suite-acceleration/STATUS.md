# uPyCore acceleration progress and recovery record

The suite-wide competitiveness goal is unfinished. Benchmark code is unchanged. All timings below assume a 12 ns period; they are projections, not measured routed timing.

## Current recoverable changes

Branch: codex/suite-recovery, based on main f15327a. Firmware uses existing bulk byte copy for unit-stride string/bytes/bytearray slices, and the scalar square-root path instead of 12 Newton iterations. No hardware datapath or compiler changes in this recovery checkpoint.

## Newly verified measurements

| Test | Historical cycles | Recovered cycles | Cycle reduction | At 12 ns |
|---|---:|---:|---:|---:|
| core_str | 36,137,718 | 29,900,130 | 17.3% | 358.802 ms |
| misc_mandel | 72,744,638 | 65,440,491 | 10.0% | 785.286 ms |

Each completed row matches the original source/harness hash and result callback. The current targets are 190.5 ms for strings and 153.923 ms for Mandelbrot, so both recovered results remain too slow. MCU targets are retained from the earlier comparison, not new same-version board measurements.

Validation: 11/11 existing slice/complex tests, 1/1 square-root-extreme test, 32/32 string tests, 8/8 targeted tests with accelerators disabled, and 8/8 targeted tests compiled by uPy2 passed. The new extreme test uses exact arithmetic expected booleans; no pinned Unix MicroPython oracle was available. These targeted checks do not replace full-suite acceptance.

## Restored character conversion fast paths

On top of the recovered checkpoint, native `chr` uses the existing ASCII character table and native `ord` reads a single byte using the existing string descriptor reader. Unicode and error handling use firmware. Invalid `chr` arguments now raise before reaching the character table.

`core_str` completed in **12,884,642 cycles** with its original source/harness hash and result callback. That is 64.3% below the historical 36,137,718 cycles and 56.9% below the 29,900,130-cycle recovery checkpoint. At 12 ns this projects to **154.616 ms**, below the 190.5 ms comparison target. The retained MCU timings have the comparability limits described above.

The 32 existing string tests and both targeted character conversion/Unicode iterator tests passed. The character conversion test also passed with uPy2 and the accelerators disabled. The implementation adds three controller states and reuses the existing scratch registers, string descriptor reader and character table. Physical timing, area and power are unmeasured.

## Restored dictionary lookup fast path

Exact `dict.get` calls now reuse the scalar lookup engine. The firmware table size search stops at the first adequate capacity. User-defined key operations remain in firmware.

`bm_wordcount` completed in **14,225,479 cycles**, 38.0% below the historical 22,934,010 cycles. At 12 ns this projects to **170.706 ms**, compared with the 110.1 ms target. The same build completed `core_str` in **12,884,690 cycles**. Both runs matched their original source/harness hashes and result callbacks.

All 30 existing tests selected by `*dict*` and `*set_grow*` passed. The new dictionary regression checked hits storing `None`, missing defaults, tombstones and a single ordered hash/equality callback pair. It passed with both compilers and with the accelerators disabled on the uPy2 run.

## Earlier observations whose raw artifacts were lost

The workspace twice reverted to an older snapshot on continuation. Previous acceleration worktrees, commits and raw logs are absent from the current filesystem and were not published to GitHub. The following values were observed earlier in this conversation, but must be reproduced before acceptance; they are NOT measurements of the recovered branch.

| Test | Earlier observed optimized cycles |
|---|---:|
| Mandelbrot | 7,899,383 |
| Wordcount | 14,224,138 |
| Instance attributes | 36,828,489 |
| Strings, later native stage | 17,925,398 |
| N-Queens | 50,307,690 |
| Float | 8,014,293 |

Missing implementation checkpoints: 378cec8, e62c96d, aac2429, 7542fa8. They contained shared scalar map insertion, type/attribute lookup, dict.get, float/type constructors, native complex arithmetic and abs, ASCII chr/ord, type predicates, callback-safe primitive sequence operations and public getattr/setattr paths. The chr(float) memory-access bug was fixed and its targeted test passed before the rollback. These changes need reconstruction and revalidation.

## Next work

Preserve a publishable remote checkpoint, restore the earlier general fast paths, then profile remaining costs. Prior profiles attributed N-Queens to iterator construction, materialization and frame transfer; attributes to wrapper/lookup overhead; strings to byte-at-a-time slicing and chr/ord; Hexiom to generic dispatch and primitive comparisons; wordcount to dict access; Mandelbrot to software complex operations; float to conversion and range reduction. Preserve callback order, descriptors, type mutation, GC roots, overflow, Unicode and rounding semantics.

No physical area, timing or power improvement is claimed. The recovered changes add no RTL. Restored hardware changes need identical synthesis constraints and activity-based power checks. Every comparable benchmark must meet its own 12 ns cycle budget before declaring the goal complete.

## Detailed implementation plan

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

## Preserved per-test budgets

| Test | Historical cycles | Reference target ms | Cycle budget at 12 ns |
|---|---:|---:|---:|
| bm_chaos | 6,945,312 | 114.600 | 9,550,000 |
| bm_fannkuch | 1,557,009 | 61.700 | 5,141,666 |
| bm_fft | 126,486,860 | n/a | n/a |
| bm_float | 10,116,524 | 63.105 | 5,258,791 |
| bm_hexiom | 57,597,921 | 194.645 | 16,220,385 |
| bm_nqueens | 115,909,110 | 210.511 | 17,542,583 |
| bm_wordcount | 22,934,010 | 110.100 | 9,175,000 |
| core_locals | 93,410,376 | 136.500 | 11,375,000 |
| core_qstr | 607,804 | 18.500 | 1,541,666 |
| core_str | 36,137,718 | 190.500 | 15,875,000 |
| core_yield_from | 10,028,604 | 52.300 | 4,358,333 |
| misc_aes | 2,344,808 | 63.979 | 5,331,562 |
| misc_mandel | 72,744,638 | 153.923 | 12,826,916 |
| misc_pystone | 12,183,102 | 116.982 | 9,748,488 |
| misc_raytrace | 11,030,762 | 122.709 | 10,225,718 |
