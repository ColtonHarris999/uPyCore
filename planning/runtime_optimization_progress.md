# Runtime optimization progress

Results for [`runtime_optimization_plan.md`](runtime_optimization_plan.md).
Cycle counts are the kernel interval measured by
`upycore/tools/runtime_profile.py` (first two `_ticks` samples), with the
pinned mpy-cross, CA and AALU on. Baseline and candidate run in separate
checkouts with the same Verilator (5.052); the passive profiler and the plain
simulator agree to the cycle on every run below. Execution times use the
plan's assumed 18 ns period.

Stages follow the plan's integration-order table: 1 bytearray, 2 borrowed
slice-assignment RHS (plan §3), 3 native pop/insert (plan §4), 4 strided
slice gather (plan §2).

## Summary

| Stage | Commit | `misc_aes` | `bm_fannkuch` | Fannkuch vs previous |
| --- | --- | ---: | ---: | ---: |
| baseline | `aca1b5e` | 59,598,294 | 44,226,732 | |
| 1 bytearray / high-bit bytes | `b66ac27` | 2,286,634 | 44,222,123 | −0.01 % |
| 2 borrowed slice RHS | `8dec49b` | 2,286,634 | 39,139,681 | −11.49 % |
| 3 native pop/insert | `3fcc6cc` | 2,286,634 | 35,803,059 | −8.53 % |
| 4 strided slice gather | `c2a8099` | 2,286,634 | 34,380,899 | −3.97 % |
| all, vs baseline | | **−96.16 %** | **−22.26 %** | |

At 18 ns: AES 1,072.8 → 41.2 ms, Fannkuch 796.1 → 618.9 ms. Results are
unchanged (`(32, True)`, `(6, 10)`) and GC counts are unchanged (AES 0,
Fannkuch 1) at every stage. Each stage was measured on top of the previous
one, so the per-stage numbers are not independent: a later stage can only
save what the earlier ones left.

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

## Stage 2: borrowed RHS for list slice assignment

Commit `8dec49b`, firmware only (`_list_setslice`).

| Fannkuch group | Stage 1 | Stage 2 |
| --- | ---: | ---: |
| `list_materialize` | 2,950,750 | 0 |
| `allocation_helper` | 3,927,831 | 2,075,263 |
| `slice_assign` | 3,305,950 | 3,642,650 |
| frame transitions | 4,533,538 | 3,876,788 |
| total | 44,222,123 | 39,139,681 |

An exact tuple, or an exact list whose item block is not the destination's,
is read in place, as MicroPython's `mp_obj_get_array` does. Self-assignment
and a shared item block still take the snapshot; subclasses and other
iterables are still materialized. Item addresses are read after
`_list_reserve`, and the RHS is a live local across it. An equal-length
replacement skips the reserve call. `_newlist` calls fall from 4,207 to
2,357 and `_list_reserve` calls from 3,086 to 1,236.

The first version compared the two item-block pointers with `!=`. On
tagged pointers that goes through `_binop` → `_type_binop` → `_equal`, and
it made Fannkuch 1.9 % slower (45,046,731) despite removing the copy. The
committed version uses identity tests and inlines the list check. Firmware
comparisons of non-numeric values should use `is` / `is not` where identity
is what is meant.

Known divergence kept on purpose (the plan says to keep the materializing
fallback): MicroPython accepts only a list or tuple RHS and raises
`TypeError: object 'X' isn't a tuple or list`; the firmware still accepts
any iterable. `containers/list_setslice_rhs` covers only cases where both
agree.

## Stage 3: native list.pop / list.insert

Commit `3fcc6cc`. Adds natives `list.pop` and `list.insert` (ABI
regenerated; native IDs 45 and 46, 8-bit field).

| Fannkuch group | Stage 2 | Stage 3 |
| --- | ---: | ---: |
| `list_pop` | 1,322,554 | 0 |
| `list_insert` | 1,337,508 | 0 |
| `allocation_helper` | 2,075,263 | 1,811,996 |
| frame transitions | 3,876,788 | 3,601,160 |
| total | 39,139,681 | 35,803,059 |

The core takes an exact list with a small-int or bool index; insert also
needs a spare slot, so it never allocates. Tails up to 16 words shift in a
core loop; longer tails go to the CA, and the core waits for the CA to drain
before it clears the vacated slot and publishes the length (the plan's
conservative rule; nothing is published while a shift is in flight). The
removed value is held in `t[3]` until delivered. Everything else calls the
firmware method before any write. The 16-word threshold is a placeholder:
it has not been tuned with a crossover sweep.

Firmware fixes found by the new test (they are bugs in the baseline too):
`pop(True)` / `pop(False)` removed the wrong item, `pop(2**40)` halted the
core with a bus fault, and `append` / `pop` / `insert` on a list subclass
instance either raised a bogus `TypeError` or read the instance as a list.
The fallbacks now follow `objlist.c` (argument count, then empty list, then
`mp_get_index`) and act on the list a subclass instance wraps.
MicroPython reads an `insert` position that is not a small int as a raw
object word, so `insert(True, x)` appends there; the test leaves bools out
of `insert`.

## Stage 4: strided list slice gather

Commit `c2a8099`. Adds the native `_wcopy_step(dst, doff, src, soff, n,
step)` and uses it in `_getslice` for list slices with a step other than 1.

| Fannkuch group | Stage 3 | Stage 4 |
| --- | ---: | ---: |
| `slice_get` | 11,690,471 | 10,136,672 |
| total | 35,803,059 | 34,380,899 |

This is a core loop, not the CA reverse mode the plan sketched: Fannkuch's
reverse slices are at most six items, below any plausible accelerator
crossover, and the port is shared so a CA gather would not move words
faster. The step is a registered byte increment (a shift, no multiplier),
so step −1 and other strides share the loop; the existing CA copy and
in-place reverse commands are unchanged.

What remains in `slice_get` (about 4,300 cycles per slice) is firmware
call overhead in `_getslice` and `_newlist`, not the copy; `slice_normalize`
(8.1 M, `_slice_range` / `_clamp` / `_slice_len`) is now the largest single
Fannkuch group. Moving normalization into the core is the next lever and is
outside this plan's initial scope.

## Verification for stages 2–4

- New oracle-differential tests: `containers/list_setslice_rhs`,
  `containers/list_pop_insert`, `containers/list_slice_step`. They match
  the oracle with CA and AALU on and off (`list_pop_insert` in all four
  modes).
- Verilator `--lint-only -Wall` of `mpy_soc` at `c2a8099`: 336 warnings,
  the same classes per file as the baseline, no errors.
- Synthesis area/timing: not measured (no Yosys slang frontend in the
  session). The new logic is FSM states that reuse existing adders,
  comparators and the port; it adds no new wide combinational path, but
  that needs a synthesis run to confirm.
