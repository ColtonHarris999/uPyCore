# BUILTIN and FUNCTION tags

Plan for an implementing agent. Baseline: `main` at `e12d6fe`. Record the
SHA you branch from in the progress file; every "before" number below is
measured on that commit.

## Goal

Two tag codes are free on `main`: `0101` (reserved) and `0111` (formerly
`SHORT_STR`, which the core never produces). Use them to remove the memory
reads the core makes today only to learn what a callee or a method is:

| Event | Today (`mpy_core.sv` on `e12d6fe`) | After |
| --- | --- | --- |
| Call a Python function | `S_CALL` reads the callee from ARGBUF, then `S_CALL_Q` reads word 0 (`S_CALL_K`) to learn it is a `FUNCTION` | The tag says so; go straight to `S_CF` |
| Call a native builtin (`len`, `isinstance`, `list.append`, the `_` firmware primitives) | Two dependent reads after the ARGBUF read: word 0 (`S_CALL_K`), then the native id at word 2 (`S_CALL_NI`) | Native id is in the payload; go straight to `S_NAT` |
| Bind a method found on a class (`S_AT_MR`) | Reads word 0 of the found value (`S_AT_VK`) to learn it is a function or builtin | The tag says so; no read |

Fixed decisions (from the design owner; do not revisit):

1. Every value stays exactly one 36-bit register. No multi-register values.
2. `CONT` keeps its meaning and encoding (`1111`, an internal pointer to an
   item array, hash table or frame block). It is renamed `CONTINUE`.
3. `0101` becomes `BUILTIN` and `0111` becomes `FUNCTION`.

Hard requirements:

- No behaviour change visible to programs: every hardware-suite golden
  stays byte-identical (do not regenerate goldens), including `hash()`,
  `id()`, `repr()` and set/dict iteration order.
- The clock-period estimate must not get worse (gate in "Timing").
- Benchmarks must show the cycle change of each tag separately and both
  together (protocol in "Benchmarks").

## Encoding

| Tag | Name | Payload | Collector traces it? |
| --- | --- | --- | --- |
| `0101` | `BUILTIN` | `[31:24]` native id, `[23:0]` byte address of the builtin's object in the image (word aligned) | No |
| `0111` | `FUNCTION` | Pointer to the function object (same 8-word layout as today) | Yes |
| `1111` | `CONTINUE` | Unchanged (was `CONT`) | Yes (unchanged) |

All other tags, `CONTROL` kinds and `MUT_COLLEC` kinds are unchanged.

Why `BUILTIN` carries an address as well as the id: a builtin object also
holds its fallback callable (word 3) and name qstr (word 4), and
`type()`, `id()`, `repr()`, `hash()` and firmware introspection (`_ld`)
read it. With the address in the payload, the object stays where it is,
its layout stays the same, and only the rare paths that need those fields
read it. The common path (a call) reads nothing.

Constraints the encoding relies on (assert them in tools, not only in RTL):

- `len(NATIVES) <= 256` (`mpy_abi.py`; today 64).
- Builtin objects exist only in the linked image, which lives in the flash
  window at `0x0000_0000` and is at most `MPY_MEM_BYTES` (512 KiB), so the
  address fits in 24 bits. `mpy_link.py` must assert `addr < 1 << 24` and
  `addr % 4 == 0` for every builtin it emits.
- Nothing allocates a builtin object at run time (verify: today only
  `emit_native` in `mpy_link.py` builds them). Because they are static, the
  collector need not trace `BUILTIN`.
- The function object keeps `ABI_OB_FUNCTION` in word 0 and the builtin
  object keeps `ABI_OB_BUILTIN` in word 0, so introspection and the slow
  paths still work.

### Canonical-tag invariant

Identity (`is`) and dict keys compare whole 36-bit words. So a function
object must only ever be referenced with the `FUNCTION` tag, and a builtin
only with `BUILTIN`. An `OBJECT`-tagged reference to either is a bug.

- Producers to change: `mpy_link.py` (every function it emits: firmware
  functions, module functions, type methods, `__build_class__`,
  `__import__`, `__repl_print__`, `make_new` entries; and `emit_native`),
  the core's `MAKE_FUNCTION`/`MAKE_CLOSURE` (`S_MF_A`, which uses
  `vobj(al_a)` today), and any firmware that builds or retags a function or
  builtin with `_alloc` or `_mk` (audit `upycore/firmware/`).
- Add a simulation-only check (`ifndef SYNTHESIS`, always on, `$error`) at
  every point where the core reads word 0 of an `OBJECT`-tagged value
  (`S_CALL_K`, `S_AT_VK`, and the other kind-read states found in the
  audit): word 0 equal to `ABI_OB_FUNCTION` or `ABI_OB_BUILTIN` there means
  a non-canonical reference. The whole hardware suite must run clean.
- Add a linker check that no emitted word is `OBJECT`-tagged with a target
  whose word 0 is `FUNCTION` or `BUILTIN`.

## Changes by component

Line numbers are from `e12d6fe`; search by state name, they will drift.

### 1. ABI (`upycore/tools/mpy_abi.py`, generated views)

- `TAG`: `"BUILTIN": 5`, `"FUNCTION": 7`, rename `"CONT"` to `"CONTINUE"`;
  remove `"RESERVED"` and `"SHORT_STR"`.
- Add the payload field constants (`BUILTIN_NID_SHIFT = 24`,
  `BUILTIN_ADDR_MASK = 0x00FF_FFFF`) and the `len(NATIVES) <= 256` assert.
- Bump `IMAGE_VERSION` (2 to 3): tag meanings changed, so `mpy_boot` must
  reject old images rather than misread them.
- Regenerate with `python3 upycore/tools/mpy_abi.py --sv` (writes
  `upycore/rtl/mpy_abi.svh` and `upycore/firmware/_abi.py`);
  `mpy_abi.py --check` must pass.
- `upycore/rtl/mpy_defs.svh` has a second, hand-written tag list
  (`MPY_TAG_*`, used by `mpy_gc.sv`, `mpy_shortlist.sv` and others). Update
  it to match, and make `mpy_abi.py --check` also compare `MPY_TAG_*`
  against `TAG`, so the two lists cannot drift again.
- Rename every `ABI_TAG_CONT` / `MPY_TAG_CONT` / `T_CONT` / `TAG_CONT` use
  to `CONTINUE` (20 sites in `mpy_core.sv`, more in the accelerator,
  linker and firmware). Pure rename; no logic change.

### 2. Core (`upycore/rtl/mpy_core.sv`)

Helpers (next to `adr()`, around line 184):

- `badr(v)`: `{8'd0, v[23:2], 2'b00}`, the builtin object's address. Do
  **not** change `adr()`; it feeds many address paths and must not gain a
  mux. Use `badr()` only where a `BUILTIN` value's object must be read.
- `is_fun(v)`, `is_bi(v)`: 4-bit tag compares.
- `vfun(a)`: `{ABI_TAG_FUNCTION, a}`.

Fast paths (each gated by its switch, see "Switches"):

- **Call dispatch** (`S_CALL_Q`, line ~2556). Extend the existing tag
  branch on `mv`; it already compares `tg(mv)` against `OBJECT`, so the
  decode depth is the same:
  - `FUNCTION` and `cfg_ftag`: `c_ismod <= 0; st <= S_CF` (no read).
  - `BUILTIN` and `cfg_btag`: `nid <= mv[31:24]; st <= S_NAT` (no read).
  - `OBJECT`, or a new tag with its switch off: today's path (read word 0,
    `S_CALL_K`). With the switch off, a `BUILTIN` must read word 0 and then
    word 2 through `badr(ab_q)`, so the off configuration costs exactly the
    cycles of today's design.
- **Builtin fallback** (`S_NAT_FB0`, line ~5682): reads word 3 of the
  callee; use `badr` for `BUILTIN` callees. The address comes from `ab_q`,
  a register, so this adds no logic after SRAM read data.
- **Method binding** (`S_AT_MR`, line ~6782): when `lk_res` is `FUNCTION`
  (with `cfg_ftag`) or `BUILTIN` (with `cfg_btag`), set
  `at_kind <= at_ty ? 2'd1 : 2'd2` and `ret()` without going to `S_AT_VK`.
  `OBJECT` keeps today's path.
- **`MAKE_FUNCTION`** (`S_MF_A`, line ~4375): push `vfun(al_a)`, not
  `vobj(al_a)`. This is a producer, so it is **not** gated by the switch.

Audit every other `tg(x) == ABI_TAG_OBJECT` (40 sites) and every
`ABI_OB_FUNCTION`/`ABI_OB_BUILTIN` compare. Put each site in a table in the
progress file with one of these outcomes:

- (a) "any object, then read word 0": must also accept `FUNCTION` (same
  address) and `BUILTIN` (via `badr`). The simple form: treat them as
  `OBJECT` there.
- (b) "is it an instance, type, exception or module": `FUNCTION` and
  `BUILTIN` can be rejected by tag with no read. Take that only if it is
  obviously correct.
- (c) "does not apply".

Known sites to check include `S_AT_K` (attribute access on a function or
builtin, e.g. `f.__name__`), `S_TYPEOF` (`type()`: answer
`builtin_function` / `function` from the tag without a read where possible),
`S_CALL_BS` (bound methods; their word 2 is a canonical `FUNCTION` or
`BUILTIN`, so re-dispatch through `S_CALL` takes the fast path),
`S_CALL_TF` (calling a type: its `make_new` may now be `BUILTIN`), the
key-equality and hash microcode, `isinstance`, and the natives `_tag`,
`_ld`, `_st`, `_typeof` and `id`.

Required equivalences:

- `hash(x)`: `FUNCTION` hashes exactly as `OBJECT` (payload address >> 1).
  `BUILTIN` hashes as `{8'd0, payload[23:0]} >> 1`, which equals today's
  hash of the same object.
- `id(x)`: the object address, as today (`badr` for `BUILTIN`).
- `_ld(p, i)` and `_typeof(p)` accept both tags. `_st` on a `BUILTIN`
  faults, as a store into the image does today.

### 3. Collector (`upycore/rtl/mpy_gc.sv`)

- Add `FUNCTION` to the pointer-tag list `cand_ptr` (line ~160). Leave
  `BUILTIN` out (its targets are static image objects).
- Rename `CONT` to `CONTINUE`.
- `upycore/tb/tb_mpy_gc.sv`: add cases showing a function reachable only
  through a `FUNCTION` word survives a collection, and a `BUILTIN` word is
  never marked.

### 4. Accelerator and hash units

- `mpy_hash.sv`: `FUNCTION` uses the `OBJECT` rule; `BUILTIN` masks the
  payload to `[23:0]` first, then applies the same rule. Update the table
  in `upycore/docs/mpy_hash.md`.
- `mpy_rehash_stream.sv` (line ~85 lists keys that need the core or
  firmware: `OBJECT`, `TUPLE`, `MUT`) and `mpy_map_engine.sv`. A function
  or builtin never has a user `__hash__` or `__eq__`, so hash and compare
  them in hardware by identity and do **not** add them to the "may need the
  firmware" list. That makes dicts and sets keyed by functions faster as
  well. If that is not clearly safe in a given unit, treat them as `OBJECT`
  there and say so in the progress file.
- `mpy_key_equal.sv`: equality of two `FUNCTION` or two `BUILTIN` keys is
  word identity.
- `mpy_shortlist.sv`, `mpy_bulk.sv`, `mpy_collection.sv`: copy words
  unchanged; check only for `CONT` renames and tag lists.

### 5. Linker and image tools

- `upycore/tools/mpy_link.py`:
  - `emit_native` (line ~656) returns
    `(T["BUILTIN"], (nid << 24) | addr)`, with the asserts above.
  - Every function value it emits gets `T["FUNCTION"]`; find them through
    `emit_value` and every `(T["OBJECT"], addr)` whose target is a function.
  - Add the canonical-tag check over the finished image.
- `upycore/tools/mpy_image.py`, `upycore/tools/mpy_gen_catalog.py`, and any
  trace, dump or decode tool that names tags: update the names and decode
  `BUILTIN` payloads.
- `upycore/targets/upycore.json`: update if it lists tags.

### 6. Firmware (`upycore/firmware/`)

- `base.py`, `_kind(x)` (line ~26): return `_ld(x, 0)` for `OBJECT` and
  `FUNCTION`, and the constant `OB_BUILTIN` for `BUILTIN` (no read). Most
  firmware code goes through `_kind`, so it needs no other change.
- Audit direct `TAG_OBJECT` / `_tag(x) == …` tests. Files with tag or kind
  references today: `attrs.py`, `builtins.py`, `iters.py`, `memview.py`,
  `calls.py`, `base.py`, `load.py`, `dicts.py`, `ops.py`, `fmt.py`,
  `strs.py`, `boot.py`, `seqs.py`, `modules.py`, `io/repl.py`, `io/irq.py`,
  `floatfmt.py`, `bigint.py`. Record each site and its outcome in the
  progress file.
- `fmt.py` `repr`: output must stay identical. Where it prints an address,
  use the object address (`_pay(x) & 0xFFFFFF` for `BUILTIN`).
- `io/irq.py` stores and calls handlers: they must stay canonical
  `FUNCTION` / `BUILTIN` values.

### 7. Dead code that encodes the old multi-register scheme

`upycore/rtl/mpy_regfile.sv` and `upycore/tb/tb_mpy_value.sv` implement the
abandoned multi-register format (`INT64`/`COMPLEX` with a `CONT` entry,
four-entry `SHORT_STR`). Nothing in `mpy_soc` instantiates them; only
`upycore/tools/unit_tests.py`, `upycore/tools/mpy_synth.py` and docs refer
to them. Removing `SHORT_STR` breaks them. Remove them, and their entries in
`unit_tests.py`, `mpy_synth.py` and `upycore/docs/mpy_memory_map.md`, **in
a separate commit** whose message says why. If the design owner objects,
that commit is easy to drop.

### 8. Generated and backend files

- `upycore/synth/hammer/converted/mpy_core.v` and `mpy_soc.v` are sv2v
  conversions. Regenerate them per `upycore/synth/hammer/README.md` if
  sv2v is available; otherwise record that they are stale, as earlier rounds
  did (`upycore/docs/hart_speed.md`).

### 9. Docs

- `upycore/docs/mpy_memory_map.md`: the tag table is already stale. It still
  shows `INT64`/`COMPLEX` as two registers, `SHORT_STR` as four, and says
  `INT64`, `COMPLEX` and `CONT` are not pointers, which `mpy_gc.sv`
  contradicts. Replace it with the as-built table (one register each; boxed
  `INT64`/`COMPLEX`; `BUILTIN`; `FUNCTION`; `CONTINUE`; the pointer list
  `INT64, COMPLEX, FUNCTION, STR, TUPLE, MUT_COLLEC, RANGE, ITER, BYTES,
  OBJECT, CONTINUE`).
- `upycore/docs/mpy_hash.md`: add the two rows.
- `README.md` and `upycore/docs/mpy_bytecode.md`: mention the call fast
  paths.
- `.cursor/skills/isca-figures/architecture.md` has the same stale tag
  table; update it or delete the table from it.
- When the work lands, move this plan to `planning/old/` per
  `planning/README.md`.

## Switches (for measurement only)

Follow the existing `CA`/`AALU` pattern in `mpy_core.sv` (parameters,
`$value$plusargs` in the `ifndef SYNTHESIS` block around line 1870,
continuous assigns from the parameters in the `else` branch):

- `parameter int BTAG = 1`, plusarg `+BTAG=`, register `cfg_btag`.
- `parameter int FTAG = 1`, plusarg `+FTAG=`, register `cfg_ftag`.

The switches gate only the consumer fast paths: call dispatch, method
binding, and any tag-based reject from the audit. Producers (linker,
`MAKE_FUNCTION`), hashing, the collector and firmware always use the new
encoding. With a switch off the core takes today's memory-read path, so one
image and one firmware measure each tag in isolation. In synthesis both are
constants, so the switches add no gates.

## Timing

The clock budget matters more than the cycles. Rules:

1. No new logic between SRAM read data (`mv`, `md`, `mt`) and `m_addr`,
   `wb_v` or the next-state register, beyond widening a case that already
   exists. `S_CALL_Q` already decodes `tg(mv)`; extend that case and add no
   new compare stage. `nid <= mv[31:24]` is a wire, not logic.
2. `adr()` stays as it is. `badr()` is used only on registered values
   (`ab_q`, `t[]`, `at_v`), never on `mv` feeding `m_addr`.
3. Tag predicates are 4-bit compares. Where a memory-read value both picks
   the next state and forms an address in the same cycle, register a
   one-bit flag first (the core already does this in several places; see
   the `lc_hit_r` and `call_fit_r` comments around line 1672).
4. Measure with the same flow before and after:
   - `python3 upycore/tools/sta/run.py mpy_core --lib <sky130 tt lib> --out build/sta/<tag>`
     on the baseline and the branch, then
     `python3 upycore/tools/sta/run.py --compare build/sta/base/sta.txt build/sta/new/sta.txt`.
     Use `--mapped` too if the baseline numbers in
     `upycore/docs/timing_10ns.md` were taken that way.
   - `python3 upycore/tools/mpy_synth.py --depth 100 mpy_core` on both, and
     list any new register endpoint in the deep set.
   - Repeat for `mpy_gc` and `mpy_collection`/`mpy_hash` if they changed.

**Gate:** the worst `mpy_core` path does not get longer than baseline by
more than measurement noise (state the number; aim for ≤ 0.5 %), and no
path through the new logic enters the top 20. If a path does, restructure
it before benchmarking. Report the area (cell count) change.

## Verification

All of these must pass on the branch, unmodified goldens:

1. `python3 upycore/tools/mpy_abi.py --check` (now also covering `MPY_TAG_*`).
2. `make test` (the hardware suite twice: `mpy-cross` bytecode and the
   on-device uPy2 compiler), `make test-unit`, `make test-host`,
   `make test-compiler`, `make check-goldens`.
3. The canonical-tag `$error` fires nowhere in any run.
4. New hardware tests, each in the most fitting existing area, with goldens
   from the unix oracle (`make oracle`, then the usual golden workflow for
   new files only):
   - identity and keys: `len is len`, `f is f`, dicts and sets keyed by
     functions and builtins, `hash(f) == hash(f)`;
   - `type(len)`, `type(f)`, `callable(...)`,
     `isinstance(f, type(f))`, and `repr` of each (matching the oracle);
   - closures, generator functions, decorators, default, keyword, `*args`
     and `**kwargs` calls;
   - bound methods both ways: instance methods, and `list.append` /
     `dict.get` taken as values and called later;
   - `staticmethod`, `classmethod`, `property`;
   - builtins as callbacks: `map(len, ...)`, `sorted(..., key=len)`,
     `filter`;
   - the builtin fallback path: `len()` of an object with `__len__`, a
     builtin called with the wrong argument count (same `TypeError` text);
   - collection: functions reachable only from a list, dict, closure,
     bound method or generator survive `gc.collect()` (follow the
     `gc/gc_mutant_*` style);
   - on-device `exec`/`eval` defining and calling functions (the
     `compiler` area);
   - the I/O image: an IRQ callback registered and fired (`io`/`irq` areas).
5. `tb_mpy_gc` and the hash unit testbench cover the new tags.
6. Old-image rejection: an image built with the old ABI fails to boot with
   `boot_err_o`, it does not run.

## Benchmarks

Builds:

- **base**: the `e12d6fe` simulator and images.
- **new**: the branch simulator and images, run under four configurations
  with one image per program:

| Config | Plusargs |
| --- | --- |
| none | `+BTAG=0 +FTAG=0` |
| BUILTIN | `+BTAG=1 +FTAG=0` |
| FUNCTION | `+BTAG=0 +FTAG=1` |
| both | `+BTAG=1 +FTAG=1` |

Workloads:

1. The paper set: MicroPython `perf_bench` at N=100, M=100 and `pystone`,
   using the commands in `docs/paper/README.md` (`shortlist_bench.py`,
   `perf_inventory.py`; `bm_pidigits` with `--bigint`).
2. Every program in `upycore/programs/bench` (`upycore/tools/bench.py`
   style: same image, all configs, outputs must match).
3. The `clock_bench.py` set (AES, Fannkuch, `timing_bench` loops, pystone).
4. Three new microbenchmarks in `upycore/programs/bench/`, so each tag has
   a workload that isolates it:
   - `call_builtin.py`: a loop of `len`, `isinstance` and `abs` calls;
   - `call_function.py`: a loop of calls to small Python functions and
     closures;
   - `call_method.py`: instance method calls plus `list.append` and
     `dict.get` method calls.

Event counters (simulation only, printed by the testbench at halt, for
example behind `+STATS`): calls by callee kind (function, builtin, bound
method, type, other), fast dispatches taken per tag, and method binds by
kind. Report them per workload, so each speedup can be explained by an event
count.

Extend `upycore/tools/bench.py` (or add a sibling script) to run the four
configurations, check that outputs are identical across them, and write
JSON.

Report in `planning/builtin_function_tags_progress.md`:

1. Per-workload cycles for base and the four new configs; speedup of
   BUILTIN alone, FUNCTION alone and both, relative to "none"; and both
   relative to base. Geometric means over the 15 `perf_bench` workloads
   with and without `core_qstr` (as `docs/paper/README.md` does), plus
   pystone separately.
2. "none" vs base. It should be within noise. If it is not, the rename or
   the audit changed a path, so find out why before reporting speedups.
3. The timing comparison and the area change. If the period estimate
   moved, report execution time (cycles × period) as `clock_bench.py` does,
   not only cycles.
4. The event counters, and one sentence per tag on where its gain comes
   from.

## Order of work and gates

| Step | Work | Gate |
| --- | --- | --- |
| 0 | Baseline: build `e12d6fe`; run all benchmarks and both timing flows; save the outputs | Numbers recorded |
| 1 | `CONT` → `CONTINUE` rename only | `make test` passes; cycles identical to base; timing identical |
| 2 | ABI, generated views, `mpy_defs.svh` check, image version | `--check` passes |
| 3 | Producers: linker and `MAKE_FUNCTION` emit the new tags; consumers treat them as `OBJECT` (audit outcome (a) everywhere), with both switches present but every fast path still unused; collector, hash and firmware updated; canonical check on | Full verification passes; "none" config within noise of base |
| 4 | `FUNCTION` fast paths (call, method bind, safe rejects) | Verification passes; timing gate |
| 5 | `BUILTIN` fast paths (call, method bind, fallback via `badr`) | Verification passes; timing gate |
| 6 | Accelerator identity hashing for both tags | Verification passes; timing gate for `mpy_collection` |
| 7 | Dead-code removal commit; docs | Tests pass |
| 8 | Benchmarks, counters, report | Report complete |

Commit at each step, so a regression can be bisected to one step.

## Risks

- **A missed `OBJECT` check** turns a function into an "unknown object":
  usually a slow path or a firmware hook, sometimes a wrong `TypeError`.
  The audit table and the new tests cover this; the canonical check covers
  the reverse mistake.
- **Hash or `id` drift** changes set and dict order and breaks goldens.
  The equivalences in "Core" prevent it; do not regenerate goldens to make
  a run pass.
- **Timing**: the call dispatch and method-bind states are near the address
  and next-state paths already flagged in `upycore/docs/timing_10ns.md`.
  Follow the timing rules; measure after steps 4–6, not only at the end.
- **Fallback callables**: `S_NAT_FB` reads the builtin object. Test the
  fallback for every native that has a `_<name>_fb` in firmware.
