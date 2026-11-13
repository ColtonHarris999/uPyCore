# BUILTIN and FUNCTION tags, and the fixed string data offset

Plan for an implementing agent. Part 1 adds the `BUILTIN` and `FUNCTION`
tags. Part 2 ("Part 2: fixed string data offset") stops the core and the
accelerator from reading a string's data-address word. The two parts are
independent; each has its own switch, so their gains are measured
separately. Baseline: `main` at `e12d6fe`. Record the
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
- Benchmarks must show the cycle change of each tag and of the string
  offset (Part 2) separately, and of all together (protocol in
  "Benchmarks").

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

## Part 2: fixed string data offset

### Why

A `STR` or `BYTES` header is `[0] len [1] hash [2] data address`, and the
bytes follow at `+12`. Word 2 exists so that `str`, `bytes`, `bytearray`
and `list` share one shape: length in word 0, data pointer in word 2. One
path (`S_DADDR`, the copy engines, firmware `_bcopy`) then handles all four.
`bytearray` and `list` need the pointer because their storage moves when
they grow. `str` and `bytes` are immutable and never move, so for them word
2 always holds `base + 12`. Both producers write exactly that: the linker's
`emit_str` (`upycore/tools/mpy_link.py`, line ~356) and the core's
`_strnew` (`mpy_core.sv`, `al_a + 32'd12`, line ~5740).

Every read of that word for a `STR`/`BYTES` value is therefore wasted:

| Site (`e12d6fe`) | Today | After |
| --- | --- | --- |
| `S_SINFO` (string info; 17 `gosub` callers, including string equality `S_STREQ` and hashing) | Three serial reads for a `STR`: `S_SI_S0` length, `S_SI_S1` hash, `S_SI_S2` data address | Two reads; the address is `adr(si_v) + 12` |
| `S_DADDR` (data address of str/bytes/bytearray/list) | One read of word 2 (`S_DADDR_M`) | No read for `STR`/`BYTES` |
| `mpy_hash.sv`, state `STR_PTR` (uncached string hash) | Reads `payload + 8` | Computes `payload + 12` |
| `mpy_key_equal.sv`, state `STR_PTR` (string key compare) | Reads `current + 8` for `STR` | Computes `current + 12` (the `QSTR` path is unchanged) |

### Fixed decisions

- **The layout does not change.** Word 2 is still written, so the image
  format, the ABI, the collector and any firmware that reads word 2 keep
  working. Only the readers change. (Dropping word 2 and moving the data to
  `+8` would also save 4 bytes per string. That is a separate, larger change
  and is out of scope here.)
- **`bytearray` and `list` keep reading word 2.** Their data moves.
- **`QSTR` keeps its descriptor path** (`S_SI_Q0`/`S_SI_Q1`).

### Invariant and how to prove it

Invariant: for every `STR` or `BYTES` value at address `b`, word 2 holds
`b + 12` and the bytes start there.

1. Add a simulation-only check (`ifndef SYNTHESIS`, `$error`) at each site
   in the table, **before** removing any read: when the tag is `STR` or
   `BYTES`, the word read from `+8` must equal the header address plus 12.
   Put the same check in `mpy_hash.sv` and `mpy_key_equal.sv`.
2. Run the whole verification list (Part 1's "Verification", items 1–2)
   with the checks on. It must run clean before step 3.
3. Audit the firmware for anything that could break the invariant: a
   `_st(s, 2, …)` on a string, or a `_mk(TAG_STR, …)` / `_mk(TAG_BYTES, …)`
   that makes a header point at foreign data. `strs.py:144` contains
   `_mk(TAG_BYTES, _pay(data)) if False else b`, a dead branch; confirm it
   cannot run, or remove it. Record the audit in the progress file.
4. Add a linker assert in `emit_str` that the data address is the header
   address plus 12.
5. Keep the checks after the reads are removed. The memory port still sees
   word 2 whenever other code reads it, and the tests should keep proving
   the invariant.

### Changes

Core (`upycore/rtl/mpy_core.sv`):

- `S_SI_S1`: for `STR`/`BYTES` (and the switch on), set
  `si_addr <= aoff(adr(si_v), 12)` and `ret()`, skipping `S_SI_S2`.
- `S_DADDR`: for `STR`/`BYTES` (and the switch on), set
  `si_addr <= aoff(adr(si_v), 12)` and `ret()` with no read. `INT`, `QSTR`
  and `MUT_COLLEC` keep today's paths.
- Audit every other read at `+8` of a value that can be a `STR` or `BYTES`
  (search `aoff(adr(`, `adr(...) + 8`), and list each site and its outcome
  in the progress file.

Accelerator:

- `mpy_hash.sv` `STR_PTR`: for a `STR`/`BYTES` key, form the data address
  as `payload + 12` and go to the data-read state without issuing the
  word-2 read. Update the "Memory reads" column for STR/BYTES in
  `upycore/docs/mpy_hash.md`.
- `mpy_key_equal.sv` `STR_PTR`: the same, for `STR` only.
- Check `mpy_map_engine.sv` and `mpy_rehash_stream.sv` for their own
  string-header reads. They currently delegate to the units above.

Timing rules (in addition to Part 1's):

- `si_v` is a register, so `aoff(adr(si_v), 12)` (the existing carry-select
  incrementer) adds nothing after SRAM read data. Do not form the address
  from `mv`/`md`.
- In `mpy_hash.sv` and `mpy_key_equal.sv`, form `payload + 12` from the
  registered key, and register it before it drives `mem_addr_o` if that
  path shows up in the timing report.
- Same gate as Part 1: no growth in the worst path of `mpy_core`,
  `mpy_collection` or `mpy_hash`, and no new logic in the top 20 paths.

Docs: `upycore/docs/mpy_memory_map.md` (state the invariant next to the
`STR` header layout) and `upycore/docs/mpy_hash.md`.

## Switches (for measurement only)

Follow the existing `CA`/`AALU` pattern in `mpy_core.sv` (parameters,
`$value$plusargs` in the `ifndef SYNTHESIS` block around line 1870,
continuous assigns from the parameters in the `else` branch):

- `parameter int BTAG = 1`, plusarg `+BTAG=`, register `cfg_btag`.
- `parameter int FTAG = 1`, plusarg `+FTAG=`, register `cfg_ftag`.
- `parameter int SOFF = 1`, plusarg `+SOFF=`, register `cfg_soff` (Part 2).
  It also reaches `mpy_hash` and `mpy_key_equal`: add a parameter to
  `mpy_soc`, pass it down, and read the same plusarg inside each unit's
  `ifndef SYNTHESIS` block, as the core does.

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
| none | `+BTAG=0 +FTAG=0 +SOFF=0` |
| BUILTIN | `+BTAG=1 +FTAG=0 +SOFF=0` |
| FUNCTION | `+BTAG=0 +FTAG=1 +SOFF=0` |
| STROFF | `+BTAG=0 +FTAG=0 +SOFF=1` |
| all | `+BTAG=1 +FTAG=1 +SOFF=1` |

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
     `dict.get` method calls;
   - `str_ops.py` (Part 2): equality of strings built at run time (not
     interned), dict lookups with run-time string keys, `in`, slicing,
     concatenation, and iteration over a `str` and a `bytes`.

Event counters (simulation only, printed by the testbench at halt, for
example behind `+STATS`): calls by callee kind (function, builtin, bound
method, type, other), fast dispatches taken per tag, method binds by kind,
and, for Part 2, the string-header reads skipped in `S_SINFO`, `S_DADDR`,
`mpy_hash` and `mpy_key_equal`. Report them per workload, so each speedup can be explained by an event
count.

Extend `upycore/tools/bench.py` (or add a sibling script) to run the four
configurations, check that outputs are identical across them, and write
JSON.

Report in `planning/builtin_function_tags_progress.md`:

1. Per-workload cycles for base and the five new configs; speedup of
   BUILTIN alone, FUNCTION alone, STROFF alone and all, relative to "none";
   and all relative to base. Geometric means over the 15 `perf_bench` workloads
   with and without `core_qstr` (as `docs/paper/README.md` does), plus
   pystone separately.
2. "none" vs base. It should be within noise. If it is not, the rename or
   the audit changed a path, so find out why before reporting speedups.
3. The timing comparison and the area change. If the period estimate
   moved, report execution time (cycles × period) as `clock_bench.py` does,
   not only cycles.
4. The event counters, and one sentence per optimization (each tag, and
   the string offset) on where its gain comes from.

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
| 7 | Part 2: string invariant checks in the core, `mpy_hash`, `mpy_key_equal`; firmware audit; linker assert | Full suite runs with no invariant `$error` |
| 8 | Part 2: `SOFF` switch; core fast paths (`S_SI_S1`, `S_DADDR`, other audited sites) | Verification passes; timing gate for `mpy_core` |
| 9 | Part 2: `mpy_hash` and `mpy_key_equal` fast paths | Verification passes; hash and key-equality unit tests pass; timing gate for `mpy_collection`/`mpy_hash` |
| 10 | Dead-code removal commit; docs | Tests pass |
| 11 | Benchmarks, counters, report | Report complete |

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
- **A string whose data is not at `+12`** (Part 2) would be read from the
  wrong place, silently. That is why step 7 proves the invariant on the
  full suite before step 8 removes a read, and why the checks stay on.
