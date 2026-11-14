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
- Steps 1–11 and the implementation audit tables are pending. The draft
  pull request is due after Step 1 passes.
