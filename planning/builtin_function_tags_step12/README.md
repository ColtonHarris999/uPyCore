# Step 12: resident-call forwarding and the P8 12 ns failing paths

## Benchmarks: CFWD

With the FUNCTION and BUILTIN tags, call dispatch no longer needs to read
the callee object, but a resident `CALL_FUNCTION`/`CALL_METHOD` still
stored the callable to ARGBUF slot 0 and read it straight back in
`S_CALL` (a load that waits for every posted argument store), and a
native then read its first argument back the same way. `CFWD`
(parameter, `+CFWD=` in simulation) copies both words from the store
data register the cycle after they are stored and loads them into
`md`/`mt`, so `S_CALL_Q` and `S_NAT_A` run on the same values without
the loads. The ARGBUF stores are unchanged, so every slow path still
finds them. `tag_bench.py` now also runs `CFWD` alone and `all+CFWD`;
the `all` column keeps its Step 11 meaning. Output matched across all
seven configurations on all 43 workloads ([results](results.json)).

| Set | all → all+CFWD | none → CFWD | Step 0 base → all+CFWD |
| --- | ---: | ---: | ---: |
| Paper suite, 15 workloads (geomean) | 1.0213× | 1.0152× | 1.0519× |
| Pystone (clock suite, 300 runs) | 1.0105× | | |
| `call_builtin` / `call_method` / `call_function` | 1.0523× / 1.0291× / 1.0216× | | |

| Workload | all | all+CFWD | CFWD gain | none → CFWD |
| --- | ---: | ---: | ---: | ---: |
| `paper/bm_chaos` | 2,452,412 | 2,421,808 | 1.0126× | 1.0096× |
| `paper/bm_fannkuch` | 985,561 | 977,887 | 1.0078× | 1.0076× |
| `paper/bm_fft` | 8,050,280 | 7,949,135 | 1.0127× | 1.0101× |
| `paper/bm_float` | 2,164,389 | 2,123,931 | 1.0190× | 1.0146× |
| `paper/bm_hexiom` | 7,368,980 | 7,171,114 | 1.0276× | 1.0186× |
| `paper/bm_nqueens` | 9,714,972 | 9,456,557 | 1.0273× | 1.0173× |
| `paper/bm_wordcount` | 3,646,262 | 3,596,489 | 1.0138× | 1.0074× |
| `paper/core_locals` | 3,005,215 | 2,914,924 | 1.0310× | 1.0177× |
| `paper/core_qstr` | 37,373 | 36,158 | 1.0336× | 1.0336× |
| `paper/core_str` | 4,343,853 | 4,159,089 | 1.0444× | 1.0269× |
| `paper/core_yield_from` | 3,114,433 | 3,114,385 | 1.0000× | 1.0000× |
| `paper/misc_aes` | 1,152,319 | 1,140,242 | 1.0106× | 1.0104× |
| `paper/misc_mandel` | 3,922,993 | 3,789,143 | 1.0353× | 1.0228× |
| `paper/misc_pystone` | 2,077,304 | 2,055,986 | 1.0104× | 1.0091× |
| `paper/misc_raytrace` | 3,902,133 | 3,812,931 | 1.0234× | 1.0161× |
| `bigint/bm_pidigits` | 1,336,664 | 1,330,745 | 1.0044× | 1.0035× |
| `clock/misc_aes` | 1,130,561 | 1,118,484 | 1.0108× | 1.0106× |
| `clock/bm_fannkuch` | 986,129 | 978,455 | 1.0078× | 1.0076× |
| `clock/int_add` | 48,663 | 48,654 | 1.0002× | 1.0002× |
| `clock/int_mul` | 54,661 | 54,652 | 1.0002× | 1.0002× |
| `clock/int64_mul` | 79,727 | 79,718 | 1.0001× | 1.0001× |
| `clock/int_pow` | 91,661 | 91,652 | 1.0001× | 1.0001× |
| `clock/int_to_float` | 117,679 | 114,670 | 1.0262× | 1.0249× |
| `clock/mixed_add` | 56,665 | 56,656 | 1.0002× | 1.0002× |
| `clock/float_add` | 53,669 | 53,660 | 1.0002× | 1.0002× |
| `clock/float_mul` | 56,669 | 56,660 | 1.0002× | 1.0002× |
| `clock/int_true_div` | 85,661 | 85,652 | 1.0001× | 1.0001× |
| `clock/pystone` | 2,047,529 | 2,026,214 | 1.0105× | 1.0092× |
| `program/bulk_extended_keys` | 3,183,029 | 3,073,949 | 1.0355× | 1.0230× |
| `program/bulk_maps` | 183,797 | 177,696 | 1.0343× | 1.0234× |
| `program/byte_moves` | 3,211,709 | 3,073,280 | 1.0450× | 1.0278× |
| `program/call_builtin` | 70,409 | 66,911 | 1.0523× | 1.0294× |
| `program/call_function` | 102,724 | 100,555 | 1.0216× | 1.0200× |
| `program/call_method` | 115,742 | 112,471 | 1.0291× | 1.0189× |
| `program/dict` | 171,517 | 170,609 | 1.0053× | 1.0035× |
| `program/float` | 460,174 | 459,813 | 1.0008× | 1.0005× |
| `program/intmath` | 426,042 | 424,985 | 1.0025× | 1.0021× |
| `program/listbuild` | 458,635 | 446,178 | 1.0279× | 1.0159× |
| `program/listops` | 415,956 | 398,578 | 1.0436× | 1.0271× |
| `program/sequence_ops` | 1,922,021 | 1,860,584 | 1.0330× | 1.0216× |
| `program/set_relations` | 1,105,178 | 1,064,426 | 1.0383× | 1.0257× |
| `program/str_ops` | 2,241,022 | 2,144,331 | 1.0451× | 1.0282× |
| `program/strings` | 769,150 | 742,414 | 1.0360× | 1.0238× |

## Timing: P8 (12 ns post-route) failing families

All 12 failing paths of P8 (`upycore_main32l_p12`, WNS −0.118 ns) were in
`u_core`. Changes:

| P8 family | Cause (converted RTL line) | Change | Cycle cost |
| --- | --- | --- | --- |
| `st` → `m_addr` (−0.118), `st` → `x3` (−0.054) | `_wcopy`/`_bcopy` (`S_N_WC`, `S_N_BC`) formed `base + ((len − 1 − i) << 2)` every word; Genus shared the subtract and add with other states (13653, 13695, 13651, 14652) | `S_N_WC0`/`S_N_BC0` place the pointers once; each step adds ±4 (±1) to registered pointers | +1 cycle per core-side copy; none with CA on (the copies ship to the accelerator) |
| `st` → `hval` (+0.057) | burst-fault halts formed `base + offset` into `hval` (12461, 8757, 8855, 9057, 9162) | `halt_sum` registers the two terms, `S_HALT_SUM` adds them | +1 cycle on a faulting halt only |
| `rf_base` → `m_addr` / `x0` / `x2` / `x3` / `st` / clock-gate enables (−0.047) | `rf[rf_base + sp − k]`: 4-bit add and decode in front of a 16-way 36-bit select | `TOS_OH=1`: `S_EXEC` reads the top three slots through one-hot flops; states that move `sp`/`rf_base` into `S_EXEC` go through `S_EXEC_RS`. **Off by default**, see below | rare `S_EXEC_RS` cycles |

Open estimate flow (`upycore/tools/sta`, mapped, sky130 tt, no wires; not
Genus ns), Step 11 head against this step ([base](sta_core_mapped_base.txt),
[new](sta_core_mapped_step12.txt)):

| Group | Step 11 | Step 12 |
| --- | ---: | ---: |
| worst (`cv_fun_g`, unchanged logic) | 9.504 | 9.534 |
| `m_addr` | 9.504 | 8.833 |
| `x0` | 8.586 | 8.679 |
| `x2` | 8.680 | 8.693 |

The first CFWD version read the two words from two more register-file
ports; that loaded `rf` and cost 0.1–0.3 ns on `rf` → `cv_fun_g` /
`m_wdata` / `x0` / `x2` in this flow, so it now takes them from
`m_wdata`. `TOS_OH=1` passed the hardware suite (551/551, with a
simulation check that the one-hot selects equal the indexed reads on
every `S_EXEC` cycle) but in this flow its extra `rf` load outweighed
the decode it removes; this flow does not see the Genus decode tree
that P8 reports, so try `TOS_OH=1` in the next Genus run if
`rf_base` → `m_addr` is still in the report.

## For the next backend run

Regenerate `converted/` and `RTL_STAMP` from this branch, synthesize at
the target period (not the 12 ns netlist), and run P&R at 12, 11 and 10 ns.
The P8 paths above 11.5 ns of data path that these changes do not touch,
in order of count: fetch `qn` → SRAM `addr_in` (29), short-list engine →
SRAM `wd_in`/`addr_in` (23), `rf_base`/`st` → `rf` (31), `st` → `m_wdata`
(16), `sp` → `lc_d` (8), FPU pow `i_r` → `cpos_r`/`cneg_r` (11).

## Sign-off-style estimate, calibrated to P8

`run.py --signoff` (pass the `sky130_fd_sc_hd__ss_100C_1v60` liberty as
`--lib`) moves the open flow toward the lab setup: Genus-style sharing of
mutually exclusive operators (no `-noshare`), the liberty's default wire
load, `dfrtp_1` clock-to-Q 0.88 ns and setup 0.22 ns as P8 reported them,
and the run's 0.1 ns setup uncertainty. ABC leaves most cells at
minimum drive and there is no placement or clock tree, so its absolute
numbers are about 1.6× the lab's: the Step 11 core's worst path is
19.50 ns where P8 needed 12.12 ns. One factor (12.12 / 19.50 = 0.62)
calibrates it; the endpoint counts below are at the lab periods times
1/0.62 (19.30, 17.69, 16.09 ns). `mpy_core` only: no SRAM-macro, fetch-
to-macro or accelerator paths.

| Lab period | Step 11 failing endpoints (registers) | Step 12 |
| --- | ---: | ---: |
| 12 ns | 2 (2) | 0 (0) |
| 11 ns | 48 (6) | 18 (5) |
| 10 ns | 695 (33) | 598 (34) |

At 12 ns the calibrated flow agrees with P8 (2 endpoints, against 12
failing paths at −0.118 ns). The scaled worst groups after this step
(lab-ns equivalent): `cv_fun_g` 11.9 and `cv_pos_g` 11.1 (wide-call
window from `rf`), `al_n` 11.4 (`x4`), FPU pow `r_r` 11.2, `x0` 11.1,
`u_hmod.r_r` 11.0; 34 registers are above 10 ns
([report](sta_core_signoff_step12.txt), [base](sta_core_signoff_base.txt)).
The calibration is one point: it does not model Genus sizing the
critical paths harder than the rest, so the 10 ns count is likely high.

## Defaults for the 12 ns run

No flags are needed: `BTAG`, `FTAG`, `SOFF` and `CFWD` default to 1 and
`TOS_OH` to 0. On the merged RTL (with `main`'s spill at 15) the
calibrated sign-off estimate has no failing `mpy_core` endpoint at the
12 ns equivalent (worst 18.86 ns there, about 11.7 lab ns);
`TOS_OH=1` measured 19.30 ns, so it stays off. `make test` passed
(unit benches, host tests, 551/551 under mpy-cross and uPy2).
`converted/` was not regenerated here (no sv2v); run
`upycore/synth/hammer/convert_rtl.sh` and commit `converted/` and
`RTL_STAMP` before `sweep.sh`, which refuses stale files.

## After main's MicroPython fixes (d33485f)

`main` at `d33485f` passed `make test` (566/566 under mpy-cross and
uPy2). Two more paths, the worst in the calibrated estimate, were cut:

| Group (lab-ns equivalent before) | Change |
| --- | --- |
| `cv_fun_g`, `cv_pos_g`, `x0`, `x2`, `stk_from`, `bl_base`, `drop_left` ← `rf` (11.9) | every `stk_depth - k` is `sd_sub(k)` = `spilled_reals + sp + ~k + !has_link`: the late `has_link` enters as a carry instead of selecting between two depth sums ahead of the subtract (low 16 bits identical for all inputs; checked on 2M random cases) |
| `al_n` ← `x4` (11.4) | list concatenation allocates `max(x4 + 3, 7)` through `alloc_nz`, without the zero test after the sum |

Calibrated sign-off estimate, merged RTL before → after
([report](sta_core_signoff_step12b.txt)): worst 18.86 → 18.40 ns (about
11.7 → 11.45 lab ns); failing endpoints at the 12 / 11 / 10 ns
equivalents 0 / 17 / 452 → 0 / 9 / 420. No cycle change.

`+STPROF` (simulation only) prints the cycles spent in each core state at
the end of a run.
