# Collection accelerator implementation status

This branch implements the queued map accelerator, **not every operation in the paper design**. It
builds on `59143bb` (the hash-unit branch), with `fb68255` as the shared main
baseline. The existing copy engine remains active. Copy and map work share one ordered two-command queue and CA memory port.

## Implemented paths

| Operation | Current implementation |
| --- | --- |
| Existing list/tuple word copies, shifts, slices, extension | Existing queued streaming `mpy_ca` |
| Core dict/set growth | Core allocates; `mpy_rehash_stream` pipelines rehash into unpublished storage; core publishes on success |
| `dict.update(dict)`, including keyword dict | Asynchronous merge when admission succeeds; source wins on duplicate keys |
| Set update/union insertion path | Asynchronous merge when destination has sufficient existing capacity |
| Set difference/intersection update | Asynchronous scan of destination, probing source, preserving destination deletion order |
| Symmetric difference and its update form | Asynchronous source scan, insert-or-remove |
| Set subset/superset and disjoint predicates | Read-only hash probes, including frozen sets and aliases |
| Byte moves in bytearrays/bytes/strings | Queued grouped byte memmove with partial-word RMW and preserved destination tags |
| List reverse | Queued in-place tagged-word swaps |
| List/tuple count, index and membership | Read-only scans through the existing equality unit; guarded software fallback |
| Callback-dependent or unsupported equality | Original core/firmware path, before accelerator writes |
| Read-only destination, same-table aliases, insufficient capacity | Original path |

Merge/algebra accepts immediate INT, QSTR, None and bool keys, plus INT64,
FLOAT, COMPLEX, STR and BYTES. `mpy_key_equal` compares numeric values with
MicroPython binary32 promotion and compares string/bytes contents, including
unaligned data. Its integer-to-float conversion is staged to keep it off a long
combinational path. **A hash match is never treated as equality.** Tuple,
frozenset and object equality remain on the core; admission rejects those
before any merge writes.

`mpy_rehash_stream` overlaps source reads, hash/modulo and serial insertion.
A four-entry key/value FIFO maintains identity and source-slot order under
backpressure. One shared `mpy_hash` serves rehash and merge; their modulo units
remain separate. Serial insertion prevents concurrent collision probes from
observing stale slots.

For callback-dependent rebuilding, firmware computes each `_uhash(k)` in the
original order, then calls `_mapinsert_hashed(c, table, alloc, key, value, hash)`.
The key/value/hash live in the rooted native argument buffer; no heap sidecar
allocation is needed. The accelerator inserts that entry and publishes its
count before a subsequent callback can observe the collection. Table and size
are captured before the callback, matching the existing firmware. The native
never invokes a callback again on fallback. This replaces unsafe up-front
batching of callbacks, rather than adding a Type Set or changing the header ABI.

`+BULK=0` selects the original core rehash and firmware map operations while
retaining the copy accelerator. `+CA=0` disables both. These controls leave the
async ALU unchanged. The new firmware's native-call overhead remains in both
controlled comparison modes; historical firmware is measured separately.

## Admission, ownership and completion

A merge/algebra command scans both tables without writing. It rejects keys
that require unsupported equality. Merge/xor also conservatively requires
`destination_used + source_used <= destination_alloc`; duplicates may cause
otherwise feasible commands to fall back. No mid-operation allocation occurs.

After admission, `_mapbulk` returns True and the core resumes. Until the final
used-count write is acknowledged, the scoreboard blocks destination header
and table reads/writes, and source header/table writes. Source reads remain
allowed. A subsequent operation on either collection therefore sees the
correct order. Qstr descriptor configuration is captured at command acceptance.
The queue also protects prepared-hash metadata against writes. GC waits for
the queue and both engines to drain, keeping tables and boxed values alive.

Rehash returns only after completion. A rejected rehash may have written its
new, unpublished table; that table is abandoned and the original collection
is unchanged. The ordinary fallback handles the operation. Old storage is
reclaimed by tracing GC rather than an explicit free command. Memory faults
are terminal, not a recoverable semantic fallback after partial mutation.
Probe walks are bounded by the allocation size, including all-tombstone maps.
Deletion writes NULL when the following slot is empty, otherwise TOMBSTONE,
matching the firmware's probe-chain rule.

Copy and bulk commands share a two-entry FIFO, including the running command.
Queued source/destination ranges enter the scoreboard immediately. Commands
execute in order and memory-port ownership changes only after outstanding
acknowledgements retire. The running copy retains its finer-grained release
of completed ranges; map commands retain whole-table ownership.

## Corrections needed in the paper/design

1. **Header layout:** the live four-word layout is used, capacity, storage
   pointer, flags. The proposed third-word Type Set would overwrite storage.
   A layout change must update the core, linker, firmware, GC, frozen images,
   and all access paths together. Do not silently repurpose existing flags.
2. **Type Set size:** four bytes hold one pointer, not an arbitrary set of
   types. Specify a growable representation, allocation failure handling,
   roots, and whether entries are strong references. Record key types for
   hashing, not dict value types. Nested tuple/frozenset keys can contain
   objects even when the outer tag is not OBJECT.
3. **Dynamic lookup:** check inherited/special-method lookup and unhashable
   `__hash__ = None`, as well as an explicit function in the immediate type.
   Runtime method replacement invalidates cached eligibility. An object's
   equality can invoke Python even if its hash is identity-based.
4. **Callback semantics:** a hash/eq callback may raise, allocate, trigger GC,
   modify either collection, or change another key/type. Define mutation
   detection, restart/fallback and exception ordering before precomputing
   hashes. A slot index is valid only while that table generation remains
   unchanged. Precomputing callbacks is not automatically equivalent to the
   runtime's interleaving of hashes, probes and comparisons.
5. **Hash overrides:** a second hash dict introduces probing and initialization
   overhead. A dense slot-indexed hash array with an explicit validity tag is
   a simpler candidate; negative hashes and zero are valid values. Choose
   using measured occupancy/memory cost. It must be a GC root while queued.
6. **Merge semantics:** specify overwrite precedence, alias/self cases, frozen
   destinations, empty inputs, mapping versus generic-iterable protocols,
   capacity planning, duplicate keys, and observable iteration order. Generic
   iterators, constructors and key/comparison callbacks stay on the core.
7. **Dependency scope:** protect source and destination headers/storage,
   result storage, override metadata, and any mutable hash inputs. Queued
   commands must participate before execution starts. Address-range retirement
   suitable for a linear copy is not generally safe for a hash-table probe.
8. **Completion:** publish pointers/counts only in a defined order; wait for
   acknowledged writes before releasing ownership or allowing GC. Specify
   faults, reset, outstanding responses and what happens to queued commands.
9. **Other large operations:** bytearray byte moves (including partial words),
   list/tuple membership and equality, count/index, sequence repetition,
   reverse, set relations/isdisjoint, and sort need explicit coverage. Sorting
   with callbacks and iteration over arbitrary Python objects cannot simply
   execute inside this accelerator. Existing word-copy routing is not proof
   that every such operation is accelerated.
10. **Timing:** compare complete operation latency including eligibility scans,
    initialization, allocation, hash metadata, memory arbitration and probing.
    A hash/modulo pipeline needs an in-order key/value metadata FIFO and
    backpressure. Simultaneous insertions must not probe stale destination
    contents. A shared unit also needs arbitration and routing measurements.

## Earlier prototype measurements (before the unified queue)

Run `python3 upycore/tools/unit_tests.py mpy_map_engine mpy_bulk mpy_ca`.
The map bench has 163 scenarios with randomized grants and delayed acks,
including overwrite, capacity rejection, unsupported-key rejection, computed
hash overrides and full tables with tombstones. The adapter bench checks early
return, source/destination scoreboard permissions and final-write retirement.
The existing randomized copy bench still passes; its isolated 32-word copy now
reports 68 cycles to **acknowledged idle**, previously 66 to the final grant.

`python3 upycore/tools/bulk_bench.py` compares identical firmware and ALU settings
across off/copy-only/bulk. The copy-only column includes the new firmware's
native-admission overhead; it is **not an untouched historical binary**.
Initial controlled cycle counts after immediate-hash shortcuts:

| Program | CA off | Copy only | Bulk |
| --- | ---: | ---: | ---: |
| dict | 306291 | 293889 | 292322 |
| listops | 1364653 | 1149577 | 1149587 |
| listbuild | 1463814 | 1415574 | 1415584 |

Yosys 0.70 `read_slang; synth -noabc -flatten; stat; ltp -noff` reports
17180 generic cells and 76 logic levels for `mpy_bulk`, including its hash and
modulo submodules. Restricting the unused recursive hash stack to one frame
reduced the initial 19120-cell design by 10.1%. The longest path is in the BPC=4 iterative modulo. This is
not technology-mapped area, routed timing, energy, or power, and not total-SoC
incremental area. Clock-frequency and power claims require physical evaluation.

The original 60 container programs passed with the hash shortcut. The new
`bulk_maps` regression separately passed (14284022 cycles) with both mpy-cross and uPy2.
Its first larger version exceeded the runner timeout; it was reduced to one
pass over the same operation cases and smaller tables, without removing cases.
Three accelerator unit benches and 13 manifest checks passed. Broader checks
are not a clean full-suite result.
The baseline's `gc_list_shrink_reclaims` requests a 40000-byte allocation on a
31488-byte heap; its MemoryError is a separate existing capacity issue.

The dedicated `programs/bench/bulk_maps.py` workload performs repeated dict
merges and set update/difference/intersection with retained capacity. Outputs
match in all five configurations. Comparing historical firmware (from the
hash-branch base) with the new firmware on the same simulator:

| Program | Historical, CA off | Historical, copy-only | New bulk |
| --- | ---: | ---: | ---: |
| dict | 305640 | 293238 | 292322 |
| bulk_maps | 3635933 | 3635526 | 1608098 |

This is a 55.8% cycle reduction (2.26x) on the dedicated bulk workload versus
historical copy-only, and 0.31% on the existing dict benchmark. The controlled
same-firmware comparison is 55.9%. Eligibility scans and setup are included.
The historical columns use the original firmware with `BULK=0`, not a separately
synthesized historical SoC. Raw results are in
`collection_accelerator_measurements.json`. Reproduce with
`python3 upycore/tools/bulk_bench.py upycore/programs/bench/bulk_maps.py --historical-ref 59143bb`.

## Unified-queue implementation validation

The added unit benches are `mpy_key_equal`, `mpy_rehash_stream` and
`mpy_collection`. Run them alongside `mpy_map_engine`, `mpy_bulk` and `mpy_ca`
with `python3 upycore/tools/unit_tests.py`. Equality covers 1,415 cases,
including all source/destination byte alignments, numeric rounding boundaries,
NaNs, signed zero, faults and output backpressure. Streaming rehash covers 18
cases and reaches three keys in flight. On the same randomized scenarios its
24,277 cycles compare with 30,711 for the serial engine (20.95% fewer).

The mixed-command bench checks capacity/backpressure, both dependency orders,
shared hash ownership, prepared hashes, final count publication, zero-length
commands, faults and reset. The full ALU bench passed after the initial
conversion refactor; the final implementation leaves ALU RTL unchanged.

Yosys 0.70 generic synthesis of the complete `mpy_collection` reports 40,439
cells and 76 logic levels. This includes the copy engine, shared hash, both
map paths, equality and queue, so it is not directly comparable to the earlier
bulk-only cell count. Registering numeric conversion reduced an intermediate
126-level path to 76. These are generic synthesis measurements, not physical
area, timing or power results.

The paper's literal Type Set/header redesign is not adopted: word 2 remains
the storage pointer. See the conservative tag-summary cache below. Aggregate
and Python callback equality, lexical sequence comparisons and callback-based
sorting retain their software paths. Physical PPA still requires the lab flow.

The 61 container regressions pass with both mpy-cross and uPy2. Five additional
string-key, hash-equivalence and GC regressions also pass. The differential
`programs/bench/bulk_extended_keys.py` additionally exercises mixed numeric and
string/bytes duplicates, colliding object hashes, nested tuple hashes, GC in
callbacks and a hash exception during growth. Its complete output (including
callback order and observed collection sizes) matches in CA-off, copy-only,
new accelerator and both historical firmware modes. The three current modes
also agree when compiled with uPy2. This is differential validation against
the original firmware, not a fresh unix-oracle run.

Reproduce these comparisons with:

```sh
python3 upycore/tools/bulk_bench.py upycore/programs/bench/bulk_extended_keys.py --historical-ref 59143bb
python3 upycore/tools/bulk_bench.py upycore/programs/bench/bulk_extended_keys.py --compiler mpyc
```

| Workload | Historical copy only | New CA off | New copy only | New accelerator |
| --- | ---: | ---: | ---: | ---: |
| dict | 293238 | 306291 | 293889 | 277648 |
| bulk_maps | 3635526 | 3670450 | 3670043 | 1439340 |
| bulk_extended_keys | 7080854 | 7103823 | 7096414 | 6705074 |

The dedicated bulk workload is 2.53x faster than historical copy-only; dict
uses 5.3% fewer cycles. The extended callback workload uses 5.3% fewer cycles
than historical copy-only. Raw results and earlier prototype measurements
are retained in `collection_accelerator_measurements.json`.

## Expanded collection paths

Native `_maprelation(a, b, op)` uses operations 5 (subset) and 6 (disjoint).
It returns 0/1 only at completion, or -1 to request the original firmware path.
Proper-subset length checks remain in firmware; supersets swap the operands.
These commands never publish a used count or change either table. Frozen sets
and same-table aliases are valid read-only inputs. Generic iterable inputs and
callback-bearing keys retain their original behavior.

`mpy_bytecopy` is a third executor behind the same two-entry command queue.
It copies groups bounded by source and destination word boundaries, chooses
forward/backward order for overlap, and uses read/modify/write to preserve
untouched bytes and destination tags. Queued and running byte commands lock
whole intersecting words. List reversal uses the same executor to swap complete
tagged values, including object references, and retires after the last write
acknowledgement. Existing word-copy performance counters count word-copy
commands only; they do not include byte moves or reversal.

Operation 7 reuses the map engine's equality unit to count or locate entries
in a list/tuple range. The core stages the search key in its argument buffer;
the queue protects it while the scan runs. Index normalization and errors stay
in firmware. The scan returns -2 for software fallback, -1 for a missing index,
or a nonnegative count/index. Float/complex, aggregate and object entries
currently fall back conservatively, preserving NaN and callback semantics.
Sequence repetition already uses the queued word-copy path. Lexical comparison
and sorting remain in software because their ordering/callback protocols differ.

### Tag-summary cache instead of a header ABI change

The map engine has two cached table summaries: base, extent, stride, occupied
count and a 16-bit key-tag bitmap. A completed admission scan creates a summary;
subsequent commands with the exact same descriptor can skip that scan. Summaries
never authorize object/aggregate callbacks and do not cache dynamic class
methods. Sequence admission additionally excludes float/complex tags.

Accepted core writes invalidate overlapping summaries, as do writes from every
accelerator executor. Collection request/completion clears both entries, covering reclamation and
address reuse. Ordinary allocation does not reclaim live storage and need not
clear summaries; the core explicitly requests GC when allocation fails. Invalidation takes priority over installation.
The SoC exposes `CA_TYPE_CACHE` (default 0); the collection module exposes
`TYPE_CACHE`. The cache is implemented and validated but disabled by default. This is a
bounded optimization of validated built-in tag eligibility, not a persistent
registry of Python classes. It needs no new allocation, roots or collection
header fields, and preserves the live four-word layout.

### Validation and physical evaluation

The byte/reversal bench covers 675 cases, all byte alignments, overlapping moves,
untouched bytes/tags, odd/even reversals, delayed grants/acks, faults and reset.
The map bench covers 260 cases including predicate results with no writes,
empty/full/tombstone/alias tables, count/index scans and unsupported-key fallback.
The cache variant additionally checks warm-cache scan reduction, both write
invalidation ports and GC/address reuse. Mixed queue tests cover byte-to-word
dependencies and partial-word scoreboard locks.

With the cache enabled, generic synthesis reports 49,271 cells and a 76-level
longest path, still in iterative modulo. The default configuration without the cache reports 46,162 cells and the
same 76-level path (14.2% more cells than the previous queue implementation).
Enabling the cache adds 3,109 cells (6.7%) but saves only 6,690 cycles (0.046%)
on the accelerated set-relations workload, so it is not justified as the
default configuration. It remains available for workloads that reuse
validated table descriptors more heavily. No mapped timing, routed area or
power claim follows from these generic measurements.

This workspace has no Genus/Innovus/OpenROAD executable or technology Liberty/LEF
files. The existing Hammer integration consumes a configured lab design and
uses the current RTL source list (including `mpy_bytecopy`). On the lab machine:

```sh
python3 upycore/synth/hammer/make_hammer_design.py \
  /path/to/configured/example /path/to/collection_design \
  --top mpy_collection --period 25
cd /path/to/collection_design
make syn
make par
```

Use identical library/corner, clock, I/O constraints and activity for comparisons.
For whole-SoC incremental area/routing use `--top mpy_soc` on both revisions and
compare the collection hierarchy plus total reports. Course configuration and
PDK files stay outside this repository. Physical evaluation remains blocked on
that environment; the generic synthesis above has completed.

The expanded implementation passes all 91 container/string regressions with
both mpy-cross and uPy2, plus hash equivalence and the two targeted GC tests.
The three differential workloads (`set_relations.py`, `sequence_ops.py`,
`byte_moves.py`) compare complete stdout/stderr and exit status against the
previous implementation (`839b011`) and CA-disabled firmware. The callback
logs and floating-point fallback output match. Both compilers were checked.
The earlier broad-suite heap-capacity limitation remains separate; these
results do not claim a clean run of every repository test.

```sh
python3 upycore/tools/unit_tests.py mpy_bytecopy mpy_map_engine mpy_map_cache mpy_collection
python3 upycore/tools/hw_tests.py --area containers --area strings --compiler mpyc
python3 upycore/tools/bulk_bench.py upycore/programs/bench/set_relations.py \
  upycore/programs/bench/sequence_ops.py upycore/programs/bench/byte_moves.py \
  --historical-ref 839b011
```

### Comparison against the previous accelerator

The previous RTL and firmware were built in an isolated checkout of `839b011`.
Both sides enable the accelerator and use `AALU=1`; outputs match exactly.
The new default has the optional type cache disabled.

| Differential workload | New CA off | Previous RTL + accelerator | New accelerator | Reduction vs previous |
| --- | ---: | ---: | ---: | ---: |
| set_relations.py | 17377357 | 14637909 | 14422223 | 1.5% |
| sequence_ops.py | 6667410 | 6472750 | 6149319 | 5.0% |
| byte_moves.py | 9661736 | 9591308 | 9427276 | 1.7% |

These workloads include assertions, construction and callback checks, so the
numbers describe complete programs rather than isolated engine throughput.
Do not conflate the comparison with the larger improvements over disabled
bulk acceleration. The benchmark driver accepts `--historical-sim` to reproduce
the exact prior-RTL comparison (and adds a `historical_bulk` result):

```sh
git worktree add --detach build/baseline-839b011 839b011
python3 build/baseline-839b011/upycore/tools/mpy_build.py sim
python3 upycore/tools/bulk_bench.py upycore/programs/bench/set_relations.py \
  upycore/programs/bench/sequence_ops.py upycore/programs/bench/byte_moves.py \
  --historical-ref 839b011 \
  --historical-sim build/baseline-839b011/build/mpy_soc/obj/Vtb_mpy_soc
```

Raw cycles, configuration and prior measurements are retained in
`collection_accelerator_measurements.json`.
