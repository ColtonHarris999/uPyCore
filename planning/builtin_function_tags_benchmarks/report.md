## Step 11 benchmark results

The [raw results](builtin_function_tags_benchmarks/results.json) include
the image and tag-stream hashes, matching program outputs, and
the event counters for every workload and switch configuration.
Timed workloads compare output after removing the measured cycle line.
Counts cover the whole boot-to-halt run. Cycle counts for kernels use
their existing measurement boundaries.

Reproduce with the pinned toolchain and submodules from the repository root.

```bash
make mpy-cross sim
python3 upycore/tools/tag_bench.py --workers 8
```

All configurations leave CA and AALU enabled. The 15 paper kernels
use N=100, M=100. Pi digits use the bigint firmware. The clock
suite uses 1,000 arithmetic-loop iterations and 300 Pystone runs.
Whole-program cases from the clock suite also appear under program.

| Workload | Base cycles | None | BUILTIN | FUNCTION | STROFF | All | None vs base |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `paper/bm_chaos` | 2,492,581 | 2,495,731 | 2,472,235 | 2,477,116 | 2,494,523 | 2,452,412 | +0.126% |
| `paper/bm_fannkuch` | 1,000,755 | 1,000,765 | 985,597 | 1,000,729 | 1,000,765 | 985,561 | +0.001% |
| `paper/bm_fft` | 8,156,344 | 8,178,758 | 8,089,904 | 8,139,134 | 8,178,758 | 8,050,280 | +0.275% |
| `paper/bm_float` | 2,202,469 | 2,215,998 | 2,181,006 | 2,199,381 | 2,215,998 | 2,164,389 | +0.614% |
| `paper/bm_hexiom` | 7,597,945 | 7,618,668 | 7,441,201 | 7,548,912 | 7,616,203 | 7,368,980 | +0.273% |
| `paper/bm_nqueens` | 10,030,763 | 10,035,900 | 9,767,643 | 9,983,229 | 10,035,900 | 9,714,972 | +0.051% |
| `paper/bm_wordcount` | 4,066,383 | 4,065,922 | 3,979,192 | 4,065,472 | 3,733,428 | 3,646,262 | -0.011% |
| `paper/core_locals` | 3,113,068 | 3,113,608 | 3,005,224 | 3,113,599 | 3,113,608 | 3,005,215 | +0.017% |
| `paper/core_qstr` | 37,388 | 37,394 | 37,382 | 37,385 | 37,394 | 37,373 | +0.016% |
| `paper/core_str` | 4,619,140 | 4,618,147 | 4,421,148 | 4,592,110 | 4,566,553 | 4,343,853 | -0.021% |
| `paper/core_yield_from` | 3,114,483 | 3,114,487 | 3,114,475 | 3,114,445 | 3,114,487 | 3,114,433 | +0.000% |
| `paper/misc_aes` | 1,168,765 | 1,168,831 | 1,168,675 | 1,156,819 | 1,164,487 | 1,152,319 | +0.006% |
| `paper/misc_mandel` | 4,081,921 | 4,083,150 | 3,949,728 | 4,056,423 | 4,083,142 | 3,922,993 | +0.030% |
| `paper/misc_pystone` | 2,101,642 | 2,105,231 | 2,098,025 | 2,088,110 | 2,101,631 | 2,077,304 | +0.171% |
| `paper/misc_raytrace` | 4,015,826 | 4,026,947 | 3,950,225 | 3,990,278 | 4,015,524 | 3,902,133 | +0.277% |
| `bigint/bm_pidigits` | 1,342,992 | 1,343,402 | 1,339,655 | 1,340,411 | 1,343,402 | 1,336,664 | +0.031% |
| `clock/misc_aes` | 1,146,970 | 1,147,073 | 1,146,917 | 1,135,061 | 1,142,729 | 1,130,561 | +0.009% |
| `clock/bm_fannkuch` | 1,001,333 | 1,001,333 | 986,165 | 1,001,297 | 1,001,333 | 986,129 | +0.000% |
| `clock/int_add` | 48,675 | 48,675 | 48,669 | 48,669 | 48,675 | 48,663 | +0.000% |
| `clock/int_mul` | 54,673 | 54,673 | 54,667 | 54,667 | 54,673 | 54,661 | +0.000% |
| `clock/int64_mul` | 79,739 | 79,739 | 79,733 | 79,733 | 79,739 | 79,727 | +0.000% |
| `clock/int_pow` | 91,673 | 91,673 | 91,667 | 91,667 | 91,673 | 91,661 | +0.000% |
| `clock/int_to_float` | 123,691 | 123,691 | 117,685 | 123,685 | 123,691 | 117,679 | +0.000% |
| `clock/mixed_add` | 56,677 | 56,677 | 56,671 | 56,671 | 56,677 | 56,665 | +0.000% |
| `clock/float_add` | 53,681 | 53,681 | 53,675 | 53,675 | 53,681 | 53,669 | +0.000% |
| `clock/float_mul` | 56,681 | 56,681 | 56,675 | 56,675 | 56,681 | 56,669 | +0.000% |
| `clock/int_true_div` | 85,673 | 85,673 | 85,667 | 85,667 | 85,673 | 85,661 | +0.000% |
| `clock/pystone` | 2,070,059 | 2,075,453 | 2,068,247 | 2,058,335 | 2,071,853 | 2,047,529 | +0.261% |
| `program/bulk_extended_keys` | 3,322,654 | 3,318,131 | 3,212,447 | 3,294,686 | 3,312,158 | 3,183,029 | -0.136% |
| `program/bulk_maps` | 190,916 | 191,054 | 185,804 | 189,115 | 190,988 | 183,797 | +0.072% |
| `program/byte_moves` | 3,388,910 | 3,393,217 | 3,242,136 | 3,370,723 | 3,385,270 | 3,211,709 | +0.127% |
| `program/call_builtin` | 74,628 | 74,680 | 70,540 | 74,587 | 74,642 | 70,409 | +0.070% |
| `program/call_function` | 104,941 | 104,991 | 104,649 | 103,104 | 104,953 | 102,724 | +0.048% |
| `program/call_method` | 121,240 | 121,411 | 117,127 | 120,088 | 121,349 | 115,742 | +0.141% |
| `program/dict` | 172,587 | 172,653 | 171,747 | 172,461 | 172,615 | 171,517 | +0.038% |
| `program/float` | 460,582 | 460,632 | 460,296 | 460,548 | 460,594 | 460,174 | +0.011% |
| `program/intmath` | 427,138 | 427,228 | 426,796 | 426,526 | 427,176 | 426,042 | +0.021% |
| `program/listbuild` | 480,751 | 480,801 | 458,793 | 480,681 | 480,763 | 458,635 | +0.010% |
| `program/listops` | 437,400 | 436,619 | 418,847 | 433,766 | 436,581 | 415,956 | -0.179% |
| `program/sequence_ops` | 2,009,834 | 2,005,206 | 1,938,772 | 1,991,208 | 2,002,293 | 1,922,021 | -0.230% |
| `program/set_relations` | 1,152,386 | 1,153,103 | 1,117,127 | 1,141,673 | 1,152,584 | 1,105,178 | +0.062% |
| `program/str_ops` | 2,370,438 | 2,371,412 | 2,276,504 | 2,351,648 | 2,355,694 | 2,241,022 | +0.041% |
| `program/strings` | 805,905 | 803,726 | 779,852 | 796,424 | 800,326 | 769,150 | -0.270% |

Speedup is reference cycles divided by measured cycles.
Projected execution times use the unmapped core estimates of
9.532 ns at Step 0 and 9.559 ns at Step 8. The mapped estimate
is 9.250 ns for both, so mapped time ratios equal cycle ratios.

| Workload | BUILTIN vs none | FUNCTION vs none | STROFF vs none | All vs none | All vs base | Base µs | All µs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `paper/bm_chaos` | 1.0095× | 1.0075× | 1.0005× | 1.0177× | 1.0164× | 23,759.282 | 23,442.606 |
| `paper/bm_fannkuch` | 1.0154× | 1.0000× | 1.0000× | 1.0154× | 1.0154× | 9,539.197 | 9,420.978 |
| `paper/bm_fft` | 1.0110× | 1.0049× | 1.0000× | 1.0160× | 1.0132× | 77,746.271 | 76,952.627 |
| `paper/bm_float` | 1.0160× | 1.0076× | 1.0000× | 1.0238× | 1.0176× | 20,993.935 | 20,689.394 |
| `paper/bm_hexiom` | 1.0238× | 1.0092× | 1.0003× | 1.0339× | 1.0311× | 72,423.612 | 70,440.080 |
| `paper/bm_nqueens` | 1.0275× | 1.0053× | 1.0000× | 1.0330× | 1.0325× | 95,613.233 | 92,865.417 |
| `paper/bm_wordcount` | 1.0218× | 1.0001× | 1.0891× | 1.1151× | 1.1152× | 38,760.763 | 34,854.618 |
| `paper/core_locals` | 1.0361× | 1.0000× | 1.0000× | 1.0361× | 1.0359× | 29,673.764 | 28,726.850 |
| `paper/core_qstr` | 1.0003× | 1.0002× | 1.0000× | 1.0006× | 1.0004× | 356.382 | 357.249 |
| `paper/core_str` | 1.0446× | 1.0057× | 1.0113× | 1.0631× | 1.0634× | 44,029.642 | 41,522.891 |
| `paper/core_yield_from` | 1.0000× | 1.0000× | 1.0000× | 1.0000× | 1.0000× | 29,687.252 | 29,770.865 |
| `paper/misc_aes` | 1.0001× | 1.0104× | 1.0037× | 1.0143× | 1.0143× | 11,140.668 | 11,015.017 |
| `paper/misc_mandel` | 1.0338× | 1.0066× | 1.0000× | 1.0408× | 1.0405× | 38,908.871 | 37,499.890 |
| `paper/misc_pystone` | 1.0034× | 1.0082× | 1.0017× | 1.0134× | 1.0117× | 20,032.852 | 19,856.949 |
| `paper/misc_raytrace` | 1.0194× | 1.0092× | 1.0028× | 1.0320× | 1.0291× | 38,278.853 | 37,300.489 |
| `bigint/bm_pidigits` | 1.0028× | 1.0022× | 1.0000× | 1.0050× | 1.0047× | 12,801.400 | 12,777.171 |
| `clock/misc_aes` | 1.0001× | 1.0106× | 1.0038× | 1.0146× | 1.0145× | 10,932.918 | 10,807.033 |
| `clock/bm_fannkuch` | 1.0154× | 1.0000× | 1.0000× | 1.0154× | 1.0154× | 9,544.706 | 9,426.407 |
| `clock/int_add` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 463.970 | 465.170 |
| `clock/int_mul` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 521.143 | 522.504 |
| `clock/int64_mul` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 760.072 | 762.110 |
| `clock/int_pow` | 1.0001× | 1.0001× | 1.0000× | 1.0001× | 1.0001× | 873.827 | 876.187 |
| `clock/int_to_float` | 1.0510× | 1.0000× | 1.0000× | 1.0511× | 1.0511× | 1,179.023 | 1,124.894 |
| `clock/mixed_add` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 540.245 | 541.661 |
| `clock/float_add` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 511.687 | 513.022 |
| `clock/float_mul` | 1.0001× | 1.0001× | 1.0000× | 1.0002× | 1.0002× | 540.283 | 541.699 |
| `clock/int_true_div` | 1.0001× | 1.0001× | 1.0000× | 1.0001× | 1.0001× | 816.635 | 818.833 |
| `clock/pystone` | 1.0035× | 1.0083× | 1.0017× | 1.0136× | 1.0110× | 19,731.802 | 19,572.330 |
| `program/bulk_extended_keys` | 1.0329× | 1.0071× | 1.0018× | 1.0424× | 1.0439× | 31,671.538 | 30,426.574 |
| `program/bulk_maps` | 1.0283× | 1.0103× | 1.0003× | 1.0395× | 1.0387× | 1,819.811 | 1,756.916 |
| `program/byte_moves` | 1.0466× | 1.0067× | 1.0023× | 1.0565× | 1.0552× | 32,303.090 | 30,700.726 |
| `program/call_builtin` | 1.0587× | 1.0012× | 1.0005× | 1.0607× | 1.0599× | 711.354 | 673.040 |
| `program/call_function` | 1.0033× | 1.0183× | 1.0004× | 1.0221× | 1.0216× | 1,000.298 | 981.939 |
| `program/call_method` | 1.0366× | 1.0110× | 1.0005× | 1.0490× | 1.0475× | 1,155.660 | 1,106.378 |
| `program/dict` | 1.0053× | 1.0011× | 1.0002× | 1.0066× | 1.0062× | 1,645.099 | 1,639.531 |
| `program/float` | 1.0007× | 1.0002× | 1.0001× | 1.0010× | 1.0009× | 4,390.268 | 4,398.803 |
| `program/intmath` | 1.0010× | 1.0016× | 1.0001× | 1.0028× | 1.0026× | 4,071.479 | 4,072.535 |
| `program/listbuild` | 1.0480× | 1.0002× | 1.0001× | 1.0483× | 1.0482× | 4,582.519 | 4,384.092 |
| `program/listops` | 1.0424× | 1.0066× | 1.0001× | 1.0497× | 1.0516× | 4,169.297 | 3,976.123 |
| `program/sequence_ops` | 1.0343× | 1.0070× | 1.0015× | 1.0433× | 1.0457× | 19,157.738 | 18,372.599 |
| `program/set_relations` | 1.0322× | 1.0100× | 1.0005× | 1.0434× | 1.0427× | 10,984.543 | 10,564.397 |
| `program/str_ops` | 1.0417× | 1.0084× | 1.0067× | 1.0582× | 1.0577× | 22,595.015 | 21,421.929 |
| `program/strings` | 1.0306× | 1.0092× | 1.0042× | 1.0450× | 1.0478× | 7,681.886 | 7,352.305 |

### Paper suite and Pystone

| Group | None vs base | BUILTIN vs none | FUNCTION vs none | STROFF vs none | All vs none | All vs base |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 15 paper workloads | 0.9988× | 1.0174× | 1.0050× | 1.0071× | 1.0300× | 1.0287× |
| 14 excluding core_qstr | 0.9987× | 1.0187× | 1.0053× | 1.0076× | 1.0321× | 1.0308× |
| Pystone, 300 runs | 0.9974× | 1.0035× | 1.0083× | 1.0017× | 1.0136× | 1.0110× |

### Event counts on the microbenchmarks with all switches on

| Workload | FUNCTION fast calls | BUILTIN fast calls | FUNCTION binds | BUILTIN binds | SINFO skips | DADDR skips | STRFIN skips | Hash skips | Equality skips |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `call_builtin` | 31 | 682 | 0 | 16 | 9 | 3 | 1 | 0 | 0 |
| `call_function` | 629 | 57 | 0 | 0 | 9 | 3 | 1 | 0 | 0 |
| `call_method` | 239 | 512 | 201 | 404 | 17 | 3 | 1 | 0 | 0 |
| `str_ops` | 6,428 | 15,818 | 160 | 0 | 2,889 | 1,923 | 641 | 0 | 0 |

FUNCTION saves a kind read per fast dispatch and classifies
function members without reading their header.

BUILTIN saves the kind and native-ID reads on dispatch and
classifies builtin members directly from the tag.

STROFF avoids pointer-word reads during string info, data address
lookup, finalization, hashing, and key equality. Cached hashes
already bypass the uncached hash reader.
