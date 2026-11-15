# Builtin/function tags and fixed string offset: progress

## Step 0 complete (2026-11-13)

The implementation branch is `tags`. Its starting point was
`56afc3e65e726f46eb780685ad439b507a06718e`, two planning commits above
the baseline `e12d6fe60528dcfecd7325df3a3dc690c678646e`. All numbers below
were measured in the detached worktree at that baseline. The
[baseline evidence](builtin_function_tags_baseline/README.md) contains
the full reports, raw benchmark results, and reproduction commands.

| Gate item | Result |
| --- | --- |
| Baseline build | Verilator 5.048 simulator and pinned `mpy-cross` built. |
| ABI and oracle | `mpy_abi.py --check` and `make oracle` passed. The oracle had four-byte pointers and binary32 floats. `make oracle-mpz` built. The unchanged golden checker passed 500 cases and reported 49 manifest exclusions from oracle comparison. |
| Paper suite | All 15 shortlist callbacks matched the documented reference. Pi digits matched the pinned MPZ oracle. |
| In-tree benchmarks | All 11 passed with identical output across the four existing CA/AALU configurations. |
| Clock benchmarks | All 23 cases returned identical output and cycle counts on a baseline-vs-baseline rerun. |
| New microbenchmarks | All four returned identical output across the existing CA/AALU configurations and matched the pinned oracle. |
| Timing and area | Unmapped and mapped STA plus generic depth captured for all five tops below. |
| Step 0 gate | **Passed.** |

### Paper workloads

Kernel cycles at N=100, M=100 with CA and AALU enabled. The 15-workload
summary set uses the rows other than `misc_pystone`.

| Workload | Baseline cycles |
| --- | ---: |
| `bm_chaos` | 2,492,581 |
| `bm_fannkuch` | 1,000,755 |
| `bm_fft` | 8,156,344 |
| `bm_float` | 2,202,469 |
| `bm_hexiom` | 7,597,945 |
| `bm_nqueens` | 10,030,763 |
| `bm_pidigits` | 1,342,992 |
| `bm_wordcount` | 4,066,383 |
| `core_locals` | 3,113,068 |
| `core_qstr` | 37,388 |
| `core_str` | 4,619,140 |
| `core_yield_from` | 3,114,483 |
| `misc_aes` | 1,168,765 |
| `misc_mandel` | 4,081,921 |
| `misc_pystone` | 2,101,642 |
| `misc_raytrace` | 4,015,826 |

### In-tree whole-program workloads

The CA+AALU column also gives the corresponding whole-program
`clock_bench.py` measurements.

| Program | Both off | CA | AALU | CA+AALU |
| --- | ---: | ---: | ---: | ---: |
| `bulk_extended_keys` | 3,593,985 | 3,350,911 | 3,563,502 | 3,322,654 |
| `bulk_maps` | 1,125,307 | 192,087 | 1,116,672 | 190,916 |
| `byte_moves` | 3,498,595 | 3,427,980 | 3,459,523 | 3,388,910 |
| `dict` | 169,748 | 177,059 | 165,276 | 172,587 |
| `float` | 545,491 | 545,484 | 460,589 | 460,582 |
| `intmath` | 457,163 | 457,139 | 427,162 | 427,138 |
| `listbuild` | 516,815 | 492,856 | 504,710 | 480,751 |
| `listops` | 536,668 | 442,816 | 531,252 | 437,400 |
| `sequence_ops` | 2,173,582 | 2,027,834 | 2,151,233 | 2,009,834 |
| `set_relations` | 1,431,168 | 1,160,412 | 1,420,973 | 1,152,386 |
| `strings` | 858,075 | 812,628 | 851,352 | 805,905 |

### Clock kernels

`clock_bench.py` uses its own AES and Fannkuch harness, 1,000 arithmetic
loop iterations, and 300 Pystone iterations. Its kernel counts use those
measurement boundaries.

| Kernel | Baseline cycles |
| --- | ---: |
| `misc_aes` | 1,146,970 |
| `bm_fannkuch` | 1,001,333 |
| `int_add` | 48,675 |
| `int_mul` | 54,673 |
| `int64_mul` | 79,739 |
| `int_pow` | 91,673 |
| `int_to_float` | 123,691 |
| `mixed_add` | 56,677 |
| `float_add` | 53,681 |
| `float_mul` | 56,681 |
| `int_true_div` | 85,673 |
| `pystone` | 2,070,059 |

### New microbenchmarks

Whole-program cycles. The [measured sources](builtin_function_tags_baseline/microbench)
are preserved with the baseline so Step 11 can reuse the same code.

| Program | Both off | CA | AALU | CA+AALU |
| --- | ---: | ---: | ---: | ---: |
| `call_builtin` | 76,141 | 76,084 | 74,685 | 74,628 |
| `call_function` | 105,796 | 105,793 | 104,944 | 104,941 |
| `call_method` | 123,736 | 122,739 | 122,237 | 121,240 |
| `str_ops` | 2,415,952 | 2,396,497 | 2,389,893 | 2,370,438 |

### Timing and cell counts

The STA delay is the worst endpoint reported by the specified Sky130 HD TT
flow. STA cell counts are flattened netlist instances, including FFBOXes
and any SRAM timing stubs. Depth and generic cell counts are from the
separate `mpy_synth.py --depth 100` netlists. The depth flow models the
collector's full-sized allocation table in logic. Use the same flow per
column for subsequent area comparisons. The target tolerance for the
worst-path gate is 0.5%.

| Top | STA mode | Worst delay (ns) | Endpoint | Endpoint bits | STA cells | Max depth | Generic cells |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |
| `mpy_core` | unmapped | 9.532 | `x0[31]` | 21,500 | 495,250 | 179 | 391,743 |
| `mpy_core` | mapped | 9.250 | `u_hmod.r_r[27]` | 21,500 | 361,159 | 179 | 391,743 |
| `mpy_gc` | unmapped | 9.116 | `wb[9]` | 2,213 | 12,727 | 46 | 108,405 |
| `mpy_gc` | mapped | 7.291 | `mem_addr_o[9]` | 2,213 | 9,923 | 46 | 108,405 |
| `mpy_collection` | unmapped | 9.366 | `bulk_engine.rehash.pipeline.modulo.rem_o[31]` | 6,955 | 59,509 | 136 | 48,118 |
| `mpy_collection` | mapped | 9.191 | `bulk_engine.engine.modulo.rem_o[31]` | 6,955 | 53,076 | 136 | 48,118 |
| `mpy_hash` | unmapped | 7.813 | `len[31]` | 1,427 | 8,878 | 68 | 6,836 |
| `mpy_hash` | mapped | 7.168 | `result[9]` | 1,427 | 7,719 | 68 | 6,836 |
| `mpy_key_equal` | unmapped | 7.730 | `OUT mem_addr_o[30]` | 948 | 7,455 | 84 | 6,174 |
| `mpy_key_equal` | mapped | 7.007 | `OUT mem_addr_o[30]` | 948 | 6,864 | 84 | 6,174 |

### Setup differences and follow-on work

- The host kernel disables i386 execution. QEMU 10.0.13 user-mode runs the
  pinned i386 ELF through a build-local launcher. Verilator supplies the
  reported cycle counts.
- YoWASP Yosys links slang statically and its WASI frontend needs a single
  worker. The depth adapter removes only the dynamic-load command and
  supplies `read_slang -j 1`, matching the STA frontend's thread count.
  Use the same adapter for the branch. The RTL, synthesis passes, timing
  constraints, and clock settings are unchanged.
- Step 0 includes all four listed new microbenchmarks, despite the plan's
  introductory count of three. Their measured sources are staged under
  planning for reuse when the benchmark harness is implemented.
- The combined implementation milestone is tracked below.

## Steps 1–3 recovery and verification

The workspace reset removed the previous uncommitted implementation and
its running jobs. The code was reconstructed from the recorded diffs
and rebuilt with Verilator 5.048 and the pinned i386 oracle under QEMU.
The baseline evidence remains at the published Step 0 revision.

This milestone combines the `CONTINUE` rename, ABI v3, and canonical
callable producers and consumers. The `BTAG` and `FTAG` switches are
present. Call and binding dispatch still issue their existing reads.
The author approved a tolerance per workload. The working threshold is
an absolute 1% cycle difference from Step 0 per workload. The timing
gate is separate.

The image version check runs at the SoC loader write because this
checkout's `mpy_boot` decodes the stream envelope. A version mismatch
raises `boot_err_o` and keeps the core in reset. The legacy value bench
still tests its original numeric encodings pending the separate
dead-code removal. Firmware and microcode continuations retain their
independent encodings.

| Surface | Audited behavior |
| --- | --- |
| Linker | Function constants and native builtin objects emit their canonical tags. The image scan rejects a callable referenced as OBJECT. |
| Core | MAKE_FUNCTION and MAKE_CLOSURE emit FUNCTION. Call, method, attribute, hash, equality, truth, type and native address paths handle the callable payload forms. |
| Core invariants | Simulated memory completions check OBJECT kind reads through the registered return state. |
| Collector | Both ordinary memory and packed frame scans follow FUNCTION. BUILTIN remains static. |
| Firmware | The dynamic code loader emits FUNCTION. Kind, callable, attribute, descriptor and formatting paths recognize callable tags. Buffered IRQ values retain their full tag. |
| Existing goldens | Existing golden files are unchanged. Two new fixtures use pinned oracle output. |

The recovered [cycle comparison](builtin_function_tags_milestone/cycles.md)
passes the 1% per-workload threshold. The largest change is `bm_float`
at +0.614%. The 15-workload cycle geomean increased by 0.112% including
`core_qstr` and 0.119% excluding it. All 11 in-tree benchmarks also
passed the per-workload threshold under all four CA/AALU combinations.

The ABI check, 502 oracle-backed golden checks, and targeted callable,
collector-root and pin-IRQ cases passed. The baseline v2 image was
rejected before execution. A deliberately mistagged boot hook triggered
the canonical check in `S_CALL_K`.

`make test` passed all 37 RTL unit benches and all 551 hardware cases
under each compiler, including both friendly REPL sessions. The compiler
suite ran 554 programs with 549 byte-exact comparisons and five allowed
float spellings. The `--nstate` audit passed. Steps 1–3 pass their
combined verification and cycle gates.

| Top and flow | Step 0 delay (ns) | Recovered delay (ns) | Step 0 cells | Recovered cells |
| --- | ---: | ---: | ---: | ---: |
| Core, mapped | 9.250 | 9.051 | 361,159 | 361,190 |
| Core, unmapped | 9.532 | 9.559 | 495,250 | 495,681 |
| GC, mapped | 7.291 | 7.291 | 9,923 | 9,924 |
| GC, unmapped | 9.116 | 9.116 | 12,727 | 12,731 |

The unmapped worst path is 0.283% longer. The traced path into `m_req`
passes through the existing FOR_ITER path and register-window address
selection. Its source is `rf[1]`. Generic core depth moved from 179 to 178 levels. The set of endpoints at
100 levels or deeper is unchanged. GC depth remains 46 levels.

### Core OBJECT and callable kind sites

| Site | Handling |
| --- | --- |
| `vobj` and `S_LIMB_NEW_TYPE` | Retain ordinary OBJECT and bigint production. |
| `bi_scalar`, `S_BIN_TYPES`, `S_BI_TRY`, `S_BI_L_COUNT` | Bigint-only fast paths. Callable operands take numeric fallback. |
| `S_CALL_Q`, `S_CALL_K`, `S_CALL_NI` | Accept all three callable/object tags and preserve the old read count. Mask the builtin address. |
| `S_CALL_BS`, `S_CALL_TF` | Pass the tagged callable back through dispatch. |
| `S_EXEC_W`, `S_EXEC` yield-from check, `S_YF_GE` | Generator and exception specializations retain their OBJECT restrictions. |
| `S_LA_R`, `S_SA` | Native instance attribute default and attribute stores keep their ordinary OBJECT checks. |
| `S_LSUB`, `S_SSUB` | Only ordinary OBJECT may be a slice. |
| `S_ROBJ`, `S_EXM`, `S_EXM_T`, `S_NAT_A` BaseException case | Exception matching and construction keep their ordinary OBJECT checks. |
| `S_GI`, `S_GH`, `S_FI_PRE`, `S_FI_R` | Iterator, generator and dict-view specializations exclude callables. |
| `S_MF_A` | Produces the canonical FUNCTION tag. |
| `S_EQ`, `S_KEYEQ`, `S_KE_OBJ` | Preserve general object equality and the tuple fallback. |
| `S_NAT_ISI` | Only an ordinary OBJECT can be the type argument. |
| `S_TYPEOF`, `S_HASH`, `S_TR` | Read the type or kind from the appropriate object address. |
| `S_AT`, `S_AT_K`, `S_AT_MR`, `S_AT_VK` | Preserve attribute lookup and callable binding reads. |
| `S_NAT_FB0`, `S_NAT_FB1` | Recover the image address from the callee reread from ARGBUF. |
| `S_NAT_LD`, `S_NAT_ST2`, native `id` | Mask builtin addresses locally. A store to flash takes the existing fault. |

### Firmware OBJECT and callable tag sites

| Site | Handling |
| --- | --- |
| `base._kind` | Reads FUNCTION kind and returns the known BUILTIN kind. |
| `attrs._special_attr` | Callable name lookup accepts the new tags. |
| `builtins.callable`, `builtins._load_attr`, `builtins.dir` | Preserve callable recognition and type-member lookup. |
| `calls._make_type` | Preserve descriptor scan and ordinary function exclusion. |
| `fmt._addr`, `fmt._repr`, `fmt._str` | Mask builtin address and reuse object formatting. |
| `ops._hashv` | Keep function identity hash and use the masked builtin address. |
| `load._load_body`, `load._is_fun` | Produce and recognize canonical FUNCTION. |
| `base._istype`, `base._isinst`, `bigint._iswide` | Type, instance, and bigint checks require ordinary OBJECT. |
| `attrs._getattr`, `attrs._setattr`, `attrs._as_index`, `attrs._subscr`, `attrs._setsubscr` | Remaining OBJECT branches handle mutable instance/module/type properties, index protocol, or slices. Callable names take the earlier special-attribute branch. |
| `builtins._int_value`, `builtins.round`, `builtins._inst_attr` | Numeric conversions and instance-only lookup retain their ordinary OBJECT checks. |
| `calls._call`, `calls.__build_class__` | User-instance/super fallback and cell-specific handling retain OBJECT. |
| `ops._type_binop`, `ops._unop`, `ops._truth`, `floatfmt` conversion | Existing user or numeric object specializations retain OBJECT. Callable truth uses the normal true result. |
| `dicts` views and mapping protocol, `iters` iterator protocol, `seqs` buffer conversion, `strs` bytes construction, `memview` buffer and slice checks | Retain checks for the existing object kinds. |
| `boot`, `io/repl`, `io/irq` exception printers | Retain instance/exception checks. |
| OBJECT allocations in `base`, `attrs`, `builtins`, `calls`, `dicts`, `iters`, `memview`, `modules` | Preserve their ordinary object layouts and tags. The only firmware FUNCTION constructor is in `load`. |

## Step 4 FUNCTION fast paths

With `FTAG=1`, FUNCTION dispatch enters `S_CF` immediately and method
binding classifies a canonical function without its kind-word read.
With `FTAG=0`, both reads remain. The builtin switch still has no fast
consumer. All four microbenchmarks matched output across the two runs.

| Microbenchmark | Switches off cycles | FUNCTION only cycles |
| --- | ---: | ---: |
| `call_function` | 104,991 | 103,104 |
| `call_builtin` | 74,680 | 74,587 |
| `call_method` | 121,411 | 120,088 |
| `str_ops` | 2,371,412 | 2,351,648 |

Regression checks with each switch value covered callable operations,
collector roots, and a pin IRQ. The ABI and compiler state audits passed.
All 37 RTL unit benches, all 551 hardware cases under each compiler, and
all 502 oracle-backed golden checks passed. The hardware logs showed no
canonical-tag assertion failures.

| Core flow | Step 0 result | Step 4 result | Step 0 cells | Step 4 cells |
| --- | ---: | ---: | ---: | ---: |
| Mapped STA | 9.250 ns | 9.250 ns | 361,159 | 361,301 |
| Unmapped STA | 9.532 ns | 9.559 ns | 495,250 | 495,729 |
| Generic depth | 179 levels | 178 levels | 391,743 | 392,580 |

The unmapped worst path retains the same 9.559 ns FOR_ITER request path
as the combined milestone. The mapped worst path starts in the existing
modulo unit. The mapped address endpoint moved within the top groups
with a start at the registered `x3[3]`, away from the call and binding
inputs. The set of endpoints at 100 generic levels or deeper is
unchanged. The [Step 4 reports](builtin_function_tags_step4/) retain the
full rankings.

## Step 5 BUILTIN fast paths

With `BTAG=1`, the dispatch state selects the native ID from the
canonical payload and skips the kind and ID word reads. The method
binding path classifies a canonical builtin without its kind-word
read. With `BTAG=0`, both consumers take the header-read paths.
Native fallback rereads ARGBUF slot 0 after the dispatch scratch
register has been reused for argument 0. It masks off the native ID
when addressing the fallback function and builtin name.

| Core flow | Step 0 result | Step 5 result | Step 0 cells | Step 5 cells |
| --- | ---: | ---: | ---: | ---: |
| Mapped STA | 9.250 ns | 9.250 ns | 361,159 | 361,103 |
| Unmapped STA | 9.532 ns | 9.559 ns | 495,250 | 495,664 |
| Generic depth | 179 levels | 178 levels | 391,743 | 392,565 |

Both worst delays match Step 4. The mapped and unmapped paths start in
the existing modulo and FOR_ITER logic respectively. The mapped address
path starts at `fbase[4]` and the state path at `sp[0]`. The native ID
and method-kind endpoints are below the top 20 in both flows. The
set of endpoints at 100 generic levels or deeper is unchanged.
The [Step 5 timing reports](builtin_function_tags_step5/) retain the
full rankings.

The same image returned identical output across all four switch
configurations for each microbenchmark. These are whole-program cycles.

| Microbenchmark | Off | BUILTIN only | FUNCTION only | Both |
| --- | ---: | ---: | ---: | ---: |
| `call_function` | 104,991 | 104,649 | 103,104 | 102,762 |
| `call_builtin` | 74,680 | 70,540 | 74,587 | 70,447 |
| `call_method` | 121,411 | 117,127 | 120,088 | 115,804 |
| `str_ops` | 2,371,412 | 2,276,504 | 2,351,648 | 2,256,740 |

The ABI check, compiler state audit, all 37 RTL unit benches, and
502 oracle-backed golden checks passed. The callable, collector-root,
and pin IRQ tests passed with `BTAG` off and on. Both full hardware
passes returned 551/551. No canonical-tag assertion fired.

## Step 6 accelerator callable keys

The shared hash engine handles FUNCTION and BUILTIN with the same
address-based identity rule used by the core. A builtin's high payload
byte encodes its native ID and is masked before hashing. The existing
exact-word equality path compares callable keys; the map admission scan
now accepts both tags, and streamed rehash uses the hardware hash.
Object and aggregate keys retain their callback handling.

The direct admission change exposed a 9.911 ns mapped path from
destination capacity to the map request address. The free-slot
subtraction now registers during the existing admission scans. The
worst paths in both flows again end in the existing modulo units.
The standalone hash combines both identity cases with a shared shift
and masks the high payload bits for BUILTIN.

| Top and flow | Step 0 delay (ns) | Step 6 delay (ns) | Step 0 cells | Step 6 cells |
| --- | ---: | ---: | ---: | ---: |
| Collection mapped | 9.191 | 9.191 | 53,076 | 53,153 |
| Collection unmapped | 9.366 | 9.366 | 59,509 | 59,579 |
| Hash mapped | 7.168 | 7.156 | 7,719 | 7,737 |
| Hash unmapped | 7.813 | 7.813 | 8,878 | 8,909 |

The collection depth is 136 levels and hash depth is 68 levels,
both unchanged. Generic cell counts move from 48,118 to 48,247 for
collection and from 6,836 to 6,877 for hash. The new capacity and
callable hash logic stays outside the top 20 paths. See the
[Step 6 timing reports](builtin_function_tags_step6/).

The ABI and compiler state checks passed. The hash benches pass
5,201 vectors, including nested callable hashes. Map and rehash benches
cover a function and builtin with the same address hash and distinguish
the tagged values. All 37 RTL unit benches and all 551 hardware tests
under each compiler passed. The oracle confirmed all 502 golden cases.
No canonical-tag assertion fired.

## Step 7 string data address invariant

An STR or BYTES header stores its inline data address, header + 12,
in word 2. The linker checks the offset in `emit_str`. The runtime
`_strnew` path writes the same value. Simulation checks compare the
stored address before any read bypass is enabled.

| Word-2 read | Scope |
| --- | --- |
| `S_SI_S2` and `S_DADDR_M` | Check immutable STR and BYTES. Mutable buffers and lists can point to separate storage. |
| `S_N_SF1` | Checks immutable STR and BYTES in `_strfin`, including the scratch-adoption path through `S_N_SF0B`. |
| `S_NAT_LD` to `S_N_RV` | Checks generic firmware word-2 reads when the base has an immutable string tag. |
| Hash and key equality `STR_PTR` | Check both immutable tags. The QSTR equality descriptor retains its own pointer and encoding. |
| `S_LS_IT`, `S_SS_IT`, `S_SL_RHS_PTR`, `S_SL_STORE_DST`, `S_UPS_P`, `S_CVK_I`, `S_LCAT_BP`, `S_INS_P`, `S_NP_P`, `S_NI_P`, `S_LA_I`, `S_LA_G2`, `S_IT_LI` | List or bytearray backing storage. Tuple paths use their existing inline word layout. STR and BYTES indexing, iteration, equality, and hashing reach `S_SINFO`. |
| Other core accesses at +8 | Callable, closure, cell, slice, instance, module, generator, iterator, bigint, or table fields. Map and rehash engines delegate string reads to hash and equality. |

Firmware slicing, bytearray conversion, concatenation, formatting,
encoding, and I/O buffers allocate immutable data through `_strnew`.
They write the inline bytes through `_data` or `_bcopy`. The `_fin`
helper updates length, and `_strfin` updates hash and ASCII metadata.
The word-2 stores in `strs.py` initialize or replace mutable bytearray
backing storage. The only direct `_mk(TAG_BYTES, ...)` is under a
literal false condition in `_barr_grow`. No live firmware path retags
external data as STR or BYTES or replaces an immutable data pointer.

The hash and key-equality vectors use inline data at varied header
addresses. Equality still covers unaligned QSTR descriptor pointers.
The existing golden files are untouched. All 37 RTL unit benches passed.
A standalone hash vector with a corrupted word 2 triggered the new
assertion. Both hardware passes returned 551/551 and the oracle
confirmed 502 golden cases. No invariant fired in the full suite.

## Step 8 core string pointer reads

`SOFF=1` uses the registered STR or BYTES header address plus 12 in
`S_SI_S1`, `S_DADDR`, and both scratch paths of `_strfin`. The latter
still enters `S_N_SF1` to initialize the hash loop. `SOFF=0` follows
the original reads and retains the simulation checks. QSTR uses its
descriptor, and mutable buffers and lists still load their backing
pointers. Step 8 only changes the core consumers.

The `str_ops` microbenchmark takes 2,256,740 cycles with `SOFF=0`
and 2,241,022 with `SOFF=1`, a 0.70% cycle reduction with identical
output. All six targeted string and bytearray tests passed with each
switch value. The RTL unit benches passed 37/37 and both hardware
passes returned 551/551. No invariant fired. All 502 oracle-backed
golden checks passed.

| Core flow | Step 0 result | Step 8 result | Step 0 cells | Step 8 cells |
| --- | ---: | ---: | ---: | ---: |
| Mapped STA | 9.250 ns | 9.250 ns | 361,159 | 361,307 |
| Unmapped STA | 9.532 ns | 9.559 ns | 495,250 | 496,177 |
| Generic depth | 179 levels | 179 levels | 391,743 | 392,700 |

The worst timing paths remain the mapped modulo path and unmapped
FOR_ITER request path. The mapped 8.450 ns request address path
starts at the existing `t[223]` register. The string address and
scratch endpoints are outside the top 20 paths. No generic endpoint
entered the set at 100 levels or deeper. See the
[Step 8 timing reports](builtin_function_tags_step8/).

## Step 9 accelerator string pointer reads

The SoC `SOFF` setting reaches the shared hash engine, the map equality
unit, and standalone hash instances in the map and rehash paths. With
the switch on, each engine forms the inline address from the registered
key and registers it before reading data. With the switch off, word 2
is read and checked as before. QSTR keeps its descriptor read.

The pointer bypass alone raised the standalone hash's mapped delay to
7.521 ns. The slow path crossed the aggregate stack's variable frame
select. Keeping the active frame in slot zero and shifting saved
parents on push/pop removed that select without adding cycles.
The standalone mapped delay is now 5.876 ns. The new inline-address
adder does not appear on the top-ranked hash or collection paths.

| Top and flow | Step 0 delay (ns) | Step 9 delay (ns) | Step 0 cells | Step 9 cells |
| --- | ---: | ---: | ---: | ---: |
| Collection mapped | 9.191 | 9.191 | 53,076 | 53,463 |
| Collection unmapped | 9.366 | 9.366 | 59,509 | 59,729 |
| Hash mapped | 7.168 | 5.876 | 7,719 | 9,028 |
| Hash unmapped | 7.813 | 7.813 | 8,878 | 10,630 |
| Key equality mapped | 7.007 | 6.884 | 6,864 | 7,006 |
| Key equality unmapped | 7.730 | 7.743 | 7,455 | 7,680 |

Generic depth is 136 levels for collection and 68 for hash, unchanged
from Step 0. Key equality moves from 84 to 85 levels. No new endpoint
enters the set at 100 levels or deeper. The
[Step 9 timing reports](builtin_function_tags_step9/) retain the rankings.

Each hash and hash-slot bench passed all 5,202 vectors with both
settings, including nested frames that resume the parent after
retiring nonempty tuple and set children. Key equality passed 1,415
cases with each setting, reducing acknowledged reads from 7,253 to
6,021. The 1-byte hash bench reduced acknowledged reads from 1,180
to 1,026. All 37 RTL unit benches passed, along with the three
targeted hardware cases for each setting. Both full hardware passes
returned 551/551, with no invariant failures. The oracle confirmed all
502 golden cases.
