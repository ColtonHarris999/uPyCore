# Runtime optimization progress

Results for [`runtime_optimization_plan.md`](runtime_optimization_plan.md).
Cycle counts are the kernel interval measured by
`upycore/tools/runtime_profile.py` (first two `_ticks` samples), with the
pinned mpy-cross, CA and AALU on. Baseline and candidate run in separate
checkouts with the same Verilator (5.052); the passive profiler and the plain
simulator agree to the cycle on every run below. Execution times use the
plan's assumed 18 ns period.

## Baseline reproduction

Commit `aca1b5e` (phase 0), rebuilt from a clean worktree:

| Kernel | Cycles | Matches phase 0 |
| --- | ---: | --- |
| `misc_aes` (1, 32) | 59,598,294 | yes |
| `bm_fannkuch` (6,) | 44,226,732 | yes |

## Phase 1: scalar bytearray load/store, high-bit bytes reads

Commit `b66ac27`. The firmware image changes (the hook-path corrections in
`attrs.py`), so this is an image-changing comparison.

| Kernel | Baseline | Phase 1 | Change | ms at 18 ns | Result | GC |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| `misc_aes` | 59,598,294 | 2,286,634 | −96.16 % | 1,072.8 → 41.2 | `(32, True)` both | 0 → 0 |
| `bm_fannkuch` | 44,226,732 | 44,222,123 | −0.01 % | 796.1 → 796.0 | `(6, 10)` both | 1 → 1 |

AES cycle groups (exclusive, they partition the interval):

| Group | Baseline | Phase 1 |
| --- | ---: | ---: |
| user bytecode | 3,578,793 | 1,968,789 |
| `bytearray_load` | 30,758,180 | 0 |
| `bytearray_store` | 10,382,904 | 0 |
| `subscr_other` (S-box `bytes` reads) | 6,345,136 | 0 |
| frame transitions | 8,529,254 | 313,818 |
| other firmware | 4,027 | 4,027 |

Every AES subscript now stays in the core: the bytearray groups and the
generic `_subscr` group, which phase 0 traced to the high-bit S-box lookups,
are empty, and with them almost all frame entry/exit into firmware.

High-bit `bytes` probe (four reads of a 4-byte table): 23,407 → 2,003
cycles, the same as the ASCII-table probe (2,003).

What changed:

- `S_LSUB` / `S_SSUB` accept an exact bytearray (`ABI_TAG_MUT` kind 3) with a
  small-int or bool index. They share the list header read and the list's
  normalize/bounds state; no new adder or comparator. Loads read the data
  pointer and the containing word and return the byte. Stores accept a
  small-int or bool value and write its low byte with `wrb` (byte enable,
  memory tag untouched), the last step of the instruction.
- `S_LS_S` no longer sends a `bytes` object to the hook because it holds a
  byte ≥ 128; only a `str` needs the code-point walk.
- Out-of-range indices, wide or custom indices, non-int values, deletion,
  slices and subclasses (which are `OBJECT`s) take the hooks unchanged. The
  error text stays in firmware, so no ABI message was added.
- Ordering: the port scoreboard compares the word-aligned address against
  bytes-mode ranges aligned down, so a byte store or load of any lane of a
  word under copy waits for the copy, the same contract firmware `_poke8`
  already relies on.

Semantic corrections on the firmware hook path, checked against the oracle
(not part of the speedup): "bytearray index out of range"; `OverflowError`
for a wide int index on `str`/`bytes`/`bytearray`; bytearray deletion is
refused before the index is checked; a store index must be an int or bool
(no `__index__`); a stored value converts by `mp_obj_get_int` rules
(`__int__`, "can't convert X to int") and keeps its low byte, wide ints
included.

Verification:

- `strings/bytearray_index` matches the oracle: all four byte lanes, 0/1
  length, negative and out-of-range indices, bools, wide and `__index__`
  indices, value truncation, wrong value types, deletion, plain and
  overriding subclasses, high-bit bytes, and reads/writes right after bulk
  copies (`bytearray(big)`, `extend`, `[:]`, slice store).
- Verilator `--lint-only -Wall` of `mpy_soc`: 336 warnings before and after,
  same classes per file, no errors.

Not done for phase 1:

- Synthesis area/timing. The repository flow needs Yosys with the slang
  frontend; it was not available in the session that made this change.
- Memory-level randomized grant/fault tests specific to the byte store. The
  change reuses `wrb` and the existing scoreboard path rather than adding a
  new memory sequence.
