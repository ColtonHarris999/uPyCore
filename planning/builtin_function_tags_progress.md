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
