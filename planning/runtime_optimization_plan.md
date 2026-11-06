# uPyCore runtime optimization plan

This is an implementation plan, not an implemented change or a speedup
forecast. It targets four general runtime improvements identified by AES and
Fannkuch. Keep benchmark sources unchanged. Use the measured design at commit
`9a20eb277b981d53a2f552027cf0f07013f428c4` as the baseline; rebase the work
onto current main before implementation and check for intervening changes.
Integrate validated changes into main, then synth, preserving synth-specific
files.


## Baseline and goals

| Workload | Current measured kernel cycles | Time at an assumed 18 ns |
| --- | ---: | ---: |
| Pure-Python AES, parameters (1, 32) | 59,598,294 | 1,072.769 ms |
| Fannkuch, parameters (6,) | 44,226,732 | 796.081 ms |

The AES run contains 5,544 scalar bytearray reads and 3,528 writes. It also
calls the finite-field helpers 3,744 times. Fannkuch executes 504 full-list
copies, 1,850 reverse-slice assignments, and 1,236 pop/insert pairs. These are
CPython operation counts for the same workload, not cycle attribution on
uPyCore.

Priority is to reduce generic runtime work without lengthening the clock
period or weakening Python semantics. Report cycle reductions and area/timing
changes separately. No hard whole-program speedup target is justified until
profiling is complete.

## Phase 0: establish attribution and reproducible comparisons

1. Restore a reproducible runner for both benchmarks with the pinned compiler,
   identical images/settings, and the same kernel measurement boundary used
   above. Preserve source, firmware, compiler, RTL and simulator versions plus
   hashes, parameters, result callbacks, accelerator flags and raw logs.
2. Add simulation-only counters or trace analysis for scalar bytearray
   load/store fallbacks, slice normalization, slice construction, slice
   assignment, list pop/insert, allocator/GC work, native argument dispatch,
   collection-command admission, queue waits, memory waits and scoreboard
   stalls. Separate user bytecode from firmware execution. Use mutually
   exclusive cycle categories; report inclusive function totals separately to
   avoid double counting nested helpers. Do not add synthesis-visible
   performance logic merely for this analysis.
3. Attribute PCs using the linked image map and callable/frame context. Count
   cycles waiting for memory and accelerator completion as well as
   instructions retired. Firmware/helper PCs alone are insufficient when the
   core is stalled or executing native FSM states.
4. Run narrow microbenchmarks covering byte reads/writes; list copies and
   reverse slices; slice assignment; and pop/insert. Include lengths 0, 1, 2,
   4, 6, 8, 16, 32, 64, 256 and larger feasible sizes. Measure mixed element
   types as well as small integers.
5. Keep baseline and candidate runs in isolated checkouts. First reproduce the
   retained baseline counts; explain discrepancies before treating new
   measurements as improvements. A simulator rebuild/version change must not
   silently become a design comparison.

Deliverable: a cycle breakdown, fixed-cost/per-element cost curves, and a
baseline-versus-candidate result file. Preserve the original 11-program suite
in all four accelerator configurations as a regression set.

## 1. Direct scalar bytearray load/store paths

### Problem and scope

`mpy_core.sv` directly handles integer indexing for bytes, lists and tuples,
but sends bytearray accesses through `ABI_HOOK_SUBSCR` /
`ABI_HOOK_SETSUBSCR`. The fallback in `firmware/attrs.py` performs general
dispatch and index checking before reaching `_byte` or `_poke8`. AES
repeatedly incurs that work.

Implement ordinary scalar access for exact native bytearray objects and
directly supported integer/bool indices first. Preserve firmware fallback for
slices, unsupported large integers, user-defined index conversion, subclass
overrides and other cases requiring Python execution. This does not introduce
an AES-specific instruction or rewrite its algorithm.

### Implementation

- Extend `S_LSUB` and `S_SSUB` with explicit bytearray classification. Reuse
  the existing memory request machinery and byte extraction/write helpers; do
  not route scalar accesses through the bulk accelerator.
- Use separate FSM stages for header/data-pointer reads, index normalization,
  bounds checks and the actual memory operation. Check an index's
  representation before narrowing it; do not truncate an unsupported wide
  integer into an apparently valid index.
- Loads read the length and data pointer, normalize a supported negative index
  once, reject an invalid index with the correct exception, read the
  containing word, and extract the selected byte as a tagged integer.
- Stores validate the index and assigned value before writing. Determine the
  pinned MicroPython rules for bool values, integer conversion, values outside
  0–255, negative values, and wrong types. Existing firmware applies `& 255`;
  if that differs from the oracle, fix both paths consistently and document
  the semantic correction separately from performance.
- Preserve the other bytes and the destination memory tag. Reuse `wrb` only
  after checking its ordering and fault contract. Do not implement an
  independent read/modify/write sequence that can lose a concurrent
  accelerator update.
- Scoreboarding must protect the complete intersecting word during
  partial-word writes. Retain correctness for interleaved SRAM banks, byte-lane
  boundaries and overlapping pending byte-copy operations.
- Retain object/index/value roots across any fallback or allocation. Ordinary
  successful accesses should allocate nothing. Once a store has side effects,
  never retry it through firmware.

### Files and compatibility

Primary files: `upycore/rtl/mpy_core.sv`, `upycore/firmware/attrs.py`;
inspect memory arbitration in `mpy_mem.sv` and `mpy_collection.sv`. No new ABI
or memory layout should be needed for a core-only scalar fast path. If shared
helpers change, regenerate and check their consumers.

### Verification and acceptance

- Differential tests against the pinned MicroPython oracle: all four byte
  lanes, zero/one-length buffers, first/last and negative indices,
  out-of-range indices, bools, wide integers, custom `__index__`, wrong value
  types, invalid byte values and subclass behavior.
- Memory-level tests with randomized grants/acks, pending copies, adjacent
  byte writes and injected faults. Check neighboring bytes and tags
  explicitly.
- Compare fast-path and fallback results and exception behavior; maintain
  coverage of the fallback itself.
- Acceptance: eligible scalar accesses stop invoking the firmware subscript
  hooks; no new allocation; direct access costs are measured; unchanged AES
  result and fewer AES cycles; no existing-suite regressions.

Timing approach: registered address and bounds operations, shared byte-lane
logic, no new wide priority mux on a critical path. Measure synthesis area and
critical paths before merging.

## 2. Accelerated reverse and strided slice copying

### Problem and design choice

For `perm[k::-1]`, `_getslice` allocates a result and copies elements one by
one in Python firmware. The existing `mpy_bytecopy.sv` reverse mode swaps
tagged words in place; it does not gather a reversed slice into a distinct
result buffer. Reusing that mode without changing its contract would be
incorrect.

Start with out-of-place tagged-word reverse copy, step = -1, because it
directly addresses Fannkuch. Keep an explicit route to arbitrary signed
strides, but add it only if measurements justify its extra state and command
fields.

### Implementation

- Leave Python index conversion, omitted-bound handling and slice
  normalization in firmware initially. `_slice_range` must distinguish an
  omitted negative-step stop from an explicit -1. It produces a validated
  start, step and element count.
- Add a narrow internal command/helper for normalized sequence copying. Keep
  forward contiguous copying on the existing word-copy path. For reverse copy,
  advance the source address by -4 and destination by +4 per tagged element.
  Transfer both payload and tag.
- Allocate the result through existing list/tuple constructors and obtain
  current backing pointers after allocation. Root source and result objects
  before any allocating call. A moved/replaced backing allocation must not
  leave a stale saved pointer.
- Restrict the first fast path to eligible exact built-in sequences and
  distinct non-overlapping source/result storage. Unsupported types and shapes
  retain the existing fallback. Do not silently expand unsupported
  tuple/string slicing semantics as part of the optimization.
- Extend the collection command queue and dispatcher explicitly, or add a
  tightly scoped engine mode. Keep the existing copy and in-place-reverse
  commands unchanged. Expose completion/fault state using established
  conventions.
- Scoreboard the entire destination interval and the bounding source interval
  through final write acknowledgement. Reverse traversal cannot use a forward
  engine's partial-release rules without a separate proof. Conservative bounds
  are acceptable initially.
- Handle empty and single-element results without unnecessary accelerator
  launches. Validate address/count arithmetic before command admission and
  avoid address-wrap bugs.
- If generic strides are added later, use a registered signed address
  increment per element. Compute/validate span bounds outside the memory
  critical path; avoid a combinational stride-by-count multiplier. Bound
  sparse accesses conservatively and document extra false stalls.
- Account for command setup overhead on Fannkuch's very short lists. Use
  measured crossover data to choose between an internal core loop and
  accelerator dispatch. A new helper that still decodes several Python
  arguments on every element would miss the goal.

### Verification and acceptance

Exhaustively compare short-list slice combinations with the oracle, including
omitted/negative/oversized bounds and steps -1, 1, and supported larger
strides; check zero-step exceptions. Test lengths 0–8, odd/even lengths, tags,
mutable element identity, bank boundaries, queue backpressure,
source-write/destination-read hazards, faults and GC fences.

Acceptance: eligible reverse slices no longer execute the per-element firmware
copy loop, return an independent list containing the same element references,
preserve every tag, and improve measured reverse-slice costs. Demonstrate
whether Fannkuch improves after accounting for queue and allocation overhead.
No numerical speedup promise until measured.

## 3. Remove redundant RHS copying in slice assignment

### Problem

`_list_setslice` unconditionally converts the RHS through `_list_of_iter`.
For an exact list, that calls `_list_of_seq`, allocates another list and
copies it. Fannkuch therefore copies an already-materialized reverse-slice
result again before assigning its elements.

This is primarily a firmware optimization and can be implemented before new
accelerator RTL.

### Implementation

- Introduce a narrowly defined borrowed-source path for an exact built-in list
  or tuple with safe non-aliasing backing storage. Record source length and
  backing description without constructing a second list. Preserve the
  existing iterable-materialization fallback.
- Keep a snapshot for self-assignment and overlapping/uncertain storage
  aliases. Test backing-range overlap, not merely unequal object pointers. Do
  not assume that every future list representation owns unique storage.
- Preserve behavior for subclasses, user iterators, callbacks and index
  conversion. Native eligibility must not bypass observable Python methods or
  change evaluation order. Resolve normalization and source inspection in an
  order validated against the oracle, including callbacks that mutate the
  destination.
- Root the RHS object across destination reserve/GC. Acquire or refresh raw
  item pointers after any allocation that can invalidate them. A saved raw
  source pointer alone is not a sufficient lifetime guarantee.
- For the common equal-length replacement case, avoid reserve work and tail
  shifting. Copy directly from the stable RHS backing storage into the
  existing destination region.
- For growing/shrinking replacement, retain the existing allocation policy and
  memmove ordering. Shift the tail in the safe direction, then copy RHS
  elements; clear obsolete tail slots after shrink so GC cannot retain removed
  objects.
- Respect pending accelerator commands before reading or modifying backing
  pointers, publishing list length or allowing GC to inspect the result. Use
  existing fences/scoreboard contracts; add a header publication rule if those
  contracts do not cover metadata.
- Keep a newly created RHS result as a normal Python object. Do not consume
  it, mutate it, or infer single ownership from the particular benchmark
  expression. This change removes the extra copy, not the semantically
  required RHS evaluation.

### Verification and acceptance

Differential tests: empty/equal/growing/shrinking replacements; tuple RHS;
self-assignment; partial overlap; callback-bearing indices/iterators;
exceptions during iteration; allocation failure; GC pressure; mutable element
identity; slices before/after the valid range. Exercise both
accelerator-enabled and disabled paths.

Acceptance: eligible built-in RHS assignments allocate no intermediate
materialization list, reduce measured allocated bytes/collections where
applicable, preserve snapshot behavior for aliases, and reduce assignment
cycles. Measure phase 3 separately, then combine with reverse-copy work: the
savings interact and must not be added as independent percentages.

## 4. Lower-overhead list.pop and list.insert

### Problem and initial scope

`list__pop` and `list__insert` execute their checks and bookkeeping in
firmware even when moving only a few elements. `_wcopy` can accelerate the
shift, but it does not remove Python-level method, argument and metadata
overhead. Fannkuch performs 1,236 pairs on six-element lists.

Use the established native-method registration and firmware fallback
mechanism, following existing native list append patterns. Optimize one
operation at a time: end-pop, indexed pop, then insert with spare capacity.
Keep allocating insert on the fallback initially.

### Implementation

- Register native entries through the canonical ABI description in
  `upycore/tools/mpy_abi.py`; regenerate ABI outputs and firmware metadata
  instead of hand-editing generated constants. Confirm native-ID capacity and
  every compiled-image consumer.
- Restrict dispatch to eligible native list methods and directly supported
  arguments. Preserve overridden subclass methods, bound-method behavior,
  default pop index, argument counts and exception handling through explicit
  fallback rules.
- Native pop: validate length/index; capture and root the removed tagged
  value; shift the tail left if necessary; clear the vacated last slot;
  publish the reduced length; return the captured value. Empty and
  invalid-index errors must match the oracle.
- Native insert: normalize/clamp the index, check capacity, shift the suffix
  right with overlap-safe ordering, store the new tagged element, then publish
  the increased length. If capacity is insufficient, fall back before
  mutation, unless a later independently validated growth path is added.
- Treat pop and insert indexing differently: pop rejects an invalid index,
  while insert clamps positions. Handle bools and unsupported wide/custom
  indices according to the existing compatibility contract.
- Evaluate two shift implementations: a small registered core copy loop for
  short tails, and the existing collection memmove path for longer tails.
  Select a crossover from measurements; do not assume an accelerator launch is
  worthwhile for five words.
- For initial correctness, complete dependent shift/write acknowledgements
  before committing metadata and returning. Relax this only with an explicit
  proof covering source reads, destination writes, list headers, GC visibility
  and queued commands. Current item-range scoreboarding does not automatically
  make every header update safe.
- Add dedicated state/scratch ownership rather than borrowing live registers
  unsafely across native calls. Preserve exception, interrupt/GC and fault
  conventions. Never fall back after a partially completed mutation.

### Verification and acceptance

Differential tests: pop default/first/middle/last, negative indices, empty
lists, insert at both ends, oversized indices, capacity boundaries, argument
errors, subclasses, object identities and aliasing references. Stress repeated
pop/insert pairs, randomized sequences against a reference model, GC
immediately after removal, overlapping shifts, queue pressure and faults.

Acceptance: eligible calls bypass the firmware method body; end-pop performs
no copy; spare-capacity insert performs no allocation; removed slots do not
keep stale references; the tiny-list microbenchmarks and unchanged Fannkuch
improve without regressions.

## Integration order and decision gates

| Stage | Change | Reason / gate |
| --- | --- | --- |
| 0 | Profiling and baseline capture | Establish which fixed and per-element costs dominate |
| 1 | Scalar bytearray fast paths | Directly targets AES; independent of list work |
| 2 | Safe borrowed RHS slice assignment | Firmware-first change; removes avoidable allocation/copy |
| 3 | Native list pop/insert | General small-list improvement; measure tiny-tail crossover |
| 4 | Reverse-copy acceleration | More invasive queue/engine work; reuse established contracts |
| 5 | Generic stride support, if justified | Proceed only for demonstrated workloads beyond step -1 |

Keep each change independently reviewable and benchmarkable. Record individual
effects, then combined effects. An isolated improvement may disappear when
another phase removes the same overhead.

## Shared validation, timing and synthesis handoff

- Run the relevant RTL benches, targeted oracle differential tests, and
  existing collection/bytecopy/GC tests after each affected phase. After
  integration, run the complete project benchmark suite in all four
  accelerator configurations and the upstream benchmark inventory. Keep the
  already observed wordcount/core_locals failures visible; they are separate
  defects, not failures to relabel as unsupported.
- Pin heap/image settings and inspect GC counters; an apparent cycle win must
  not come from skipping work or changing the benchmark. Check that direct
  runtime operations have identical observable results and exceptions.
- Run syntax/lint and synthesis checks on the actual top-level integration.
  Compare cell area, register count, memory inference, worst paths and
  configured constraints. Continue using 18 ns for reported execution times,
  while checking against the repository's actual synthesis constraint and the
  project's 100 MHz objective; passing at 18 ns alone does not establish
  100 MHz.
- Prefer registered FSM work, existing byte-write machinery, shared memory
  arbitration and bounded command fields. Do not create a long single-cycle
  slice-normalization or large native-dispatch path to save runtime cycles.
- A cycle reduction is not enough if physical clock period worsens. Compare
  execution time as cycles times the independently supported clock period;
  compare area and power separately. Post-route claims require post-route
  reports from the backend flow.
- For synth integration, update explicit RTL source lists/filelists,
  generated/converted RTL, manifests, ABI-dependent firmware images,
  conversion/elaboration fingerprints, and flow documentation when affected.
  Preserve existing SRAM macro wrappers, bank geometry, constraints and
  branch-specific settings unless the design change actually requires an
  update. Never add false/multicycle paths to conceal new logic delays.
- Final handoff: source changes, reproducible runner, targeted correctness
  evidence, before/after cycle breakdown, allocator/GC data, synthesis results
  and remaining timing/coverage limitations. Merge main first, then integrate
  into synth with its configuration refresh.

## Expected outcome and remaining limits

Bytearray access should remove a substantial repeated software path from AES,
but function-call and attribute overhead will remain. List improvements should
remove repeated normalization, allocation and short-copy dispatch costs from
Fannkuch, but it will still enumerate permutations and create required slice
objects. The measurements above do not establish how much each phase will
save. Set a quantitative next-step target after phase 0 and validate it on
unchanged benchmarks rather than promising parity with a particular MCU.
