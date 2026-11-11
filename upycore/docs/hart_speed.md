# Hart speed round: shorter clock, fewer cycles

Starting point: `main` at `1b44d1e`. Score: execution time = cycles × clock
period, on the paper's perf_bench kernels (15 shortlist cases plus
`bm_pidigits`), `+CA=1 +AALU=1`, N=100 M=100.

**Every period below is the open-flow pre-placement estimate**
(`upycore/tools/sta`, unmapped, `--no-fsm` on both trees, sky130 typical
corner, no wires). It is not a Genus or Innovus number; no post-route period
is claimed. No timing exception, false path or constraint was changed.

## Result

| | `1b44d1e` | This round | Change |
| --- | ---: | ---: | ---: |
| `mpy_core` worst reg-to-reg path | 15.689 ns (`dq_n` → `pc`) | 10.332 ns (`sp` → `st`) | −34.1 % |
| `mpy_soc` worst reg-to-reg path | 16.105 ns (`c_pend` → copy engine `rpend`) | 10.332 ns (`u_core.st`) | −35.8 % |
| Period used for the score (the SoC's) | 16.105 ns | 10.332 ns | ×0.642 |
| Kernel cycles, geometric mean (16 kernels) | | | ×0.872 |
| **Kernel execution time, geometric mean** | | | **×0.559 (1.79× faster)** |
| Worst single kernel | | | ×0.591 (`bm_fannkuch`) |

Every kernel takes fewer cycles **and** runs on the shorter period; no
kernel is slower. Results (`RESULT` callbacks) are identical to the
baseline on all 16.

The 10 ns target is **not** reached in this estimate: three groups remain
above it (`st` 10.33, the map engine's request 10.20, `m_addr`/`c_addr`
10.06) and a cluster of about ten sits at 9.9–10.0 ns (list below).
If routing adds the same fraction as on the last post-route run (18 ns),
the scaled figure is about 18 × 10.332 / 16.105 ≈ 11.5 ns; that scaling is
an assumption, not a measurement.

## Per benchmark

Cycles are `run()` alone (`bench_ticks`), from `shortlist_bench.py` and, for
`bm_pidigits`, `perf_inventory.py --bigint` (MPZ oracle), each run in its own
tree so firmware and RTL are measured together (the firmware did not
change). Time = cycles × the SoC's estimated period.

| Benchmark | Cycles before | Cycles after | Cycles | Period before | Period after | Time before (ms) | Time after (ms) | Time ratio | Pyboard v1.0 (ms) | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `bm_chaos` | 3,952,735 | 3,415,375 | -13.59 % | 16.105 ns | 10.332 ns | 63.66 | 35.29 | 0.554 | 140.1 | same |
| `bm_fannkuch` | 1,088,988 | 1,003,198 | -7.88 % | 16.105 ns | 10.332 ns | 17.54 | 10.37 | 0.591 | 82.3 | same |
| `bm_fft` | 10,293,659 | 9,403,405 | -8.65 % | 16.105 ns | 10.332 ns | 165.78 | 97.16 | 0.586 | 329.5 | same |
| `bm_float` | 3,292,939 | 2,884,645 | -12.40 % | 16.105 ns | 10.332 ns | 53.03 | 29.80 | 0.562 | 43.8 | same |
| `bm_hexiom` | 11,580,088 | 10,132,997 | -12.50 % | 16.105 ns | 10.332 ns | 186.50 | 104.69 | 0.561 | 218.6 | same |
| `bm_nqueens` | 13,953,480 | 12,342,264 | -11.55 % | 16.105 ns | 10.332 ns | 224.72 | 127.52 | 0.567 | 243.2 | same |
| `bm_wordcount` | 7,774,990 | 6,604,660 | -15.05 % | 16.105 ns | 10.332 ns | 125.22 | 68.24 | 0.545 | 168.9 | same |
| `core_locals` | 6,167,342 | 4,900,777 | -20.54 % | 16.105 ns | 10.332 ns | 99.33 | 50.63 | 0.510 | 198.6 | same |
| `core_qstr` | 78,850 | 61,539 | -21.95 % | 16.105 ns | 10.332 ns | 1.27 | 0.64 | 0.501 | 19.6 | same |
| `core_str` | 6,973,563 | 5,944,789 | -14.75 % | 16.105 ns | 10.332 ns | 112.31 | 61.42 | 0.547 | 232.0 | same |
| `core_yield_from` | 4,449,947 | 4,025,391 | -9.54 % | 16.105 ns | 10.332 ns | 71.67 | 41.59 | 0.580 | 56.2 | same |
| `misc_aes` | 1,510,327 | 1,370,947 | -9.23 % | 16.105 ns | 10.332 ns | 24.32 | 14.16 | 0.582 | 78.5 | same |
| `misc_mandel` | 5,390,732 | 4,948,750 | -8.20 % | 16.105 ns | 10.332 ns | 86.82 | 51.13 | 0.589 | 126.3 | same |
| `misc_pystone` | 3,496,801 | 2,946,340 | -15.74 % | 16.105 ns | 10.332 ns | 56.32 | 30.44 | 0.541 | 126.1 | same |
| `misc_raytrace` | 6,533,393 | 5,666,797 | -13.26 % | 16.105 ns | 10.332 ns | 105.22 | 58.55 | 0.556 | 138.5 | same |
| `bm_pidigits` | 1,510,982 | 1,383,642 | -8.43 % | 16.105 ns | 10.332 ns | 24.33 | 14.30 | 0.587 | 98.0 | same |

Geometric mean over 16: cycles x0.872, time x0.559 (1.79x faster); worst single time ratio 0.591, best 0.501.

The Pyboard column is `docs/paper/benchmark-board-ms.csv`, for scale only
(different measurement conditions).

### clock_bench (same images on both simulators, RTL effect only)

`clock_bench.py --before <1b44d1e sim> --after <this sim> --before-ns 16.105 --after-ns 10.332`:
all 23 workloads take fewer cycles (−0.1 % to −20.9 %); execution time
×0.507 (`listbuild`) to ×0.641 (`int_pow`). The arithmetic loops gain
least (−0.1 to −0.2 %): they are ALU-bound, and the new states below cost
float ** and float→int a cycle each. Full output:
`build/clock_bench` in the measuring tree (not committed).

## Where the cycles went (profile first)

`runtime_profile.py --suite` (new: any perf_bench kernel; per-opcode cycle
counters in the passive profiler) on the baseline, all 15 kernels: about
30 % of all cycles were `S_MWAIT`, the core waiting for its own loads, and
6–10 % were `S_SCR`, moving a subsystem's scratch image (the dict-lookup,
attribute or iterator registers) between flops and SRAM. Two changes take
most of that:

| Change | What it buys |
| --- | --- |
| `mpy_mem` `EARLY` ports: the core's and the fetch queue's answer comes straight from the SRAM cycle (block select, hold select) into their own flops (`md`, the queue), instead of through `mpy_mem`'s output registers | one cycle less on every core load and every fetch word |
| The scratch image is dropped when an instruction is decoded (`scr_id <= SCR_NONE` in `S_DEC`); no image is live across instructions, each user writes its fields before reading them, so the next subsystem no longer stores the old image first | 8 (store) or 16 (store + reload) cycles less per subsystem switch |

Correctness note on `EARLY`: a bridge (I/O) access is answered two clocks
after it is taken (`io_q_v`, then `sim_ack`). With early memory answers a
core load granted in the clock between would be answered in the same
clock and one ack was lost (`io/uart_rx` hung). `mpy_soc` now holds core
grants while `io_q_v` (a flop) is set.

## Critical paths before and after

### `mpy_core`, the 12 worst groups before

| Register group | Before | After | Start of the worst path (before) |
| --- | ---: | ---: | --- |
| `pc` | 15.689 | 9.207 | `dq_n[2]` |
| `st` | 15.458 | 10.332 | `dq_n[2]` |
| `u_alu.u_fpu.state_r` | 14.590 | 7.052 | `u_alu.fb64_r[52]` |
| `u_alu.u_fpu.pow_res` | 14.480 | 6.939 | `u_alu.u_fpu.u_pow.pexp_r[2]` |
| `u_alu.u_fpu.u_div.s1_exp_a_r` | 14.012 | 9.473 | `u_alu.u_fpu.state_r[0]` |
| `halt_value_o` | 13.785 | 8.632 | `dq_n[2]` |
| `al_n` | 13.738 | 8.970 | `sA[226]` |
| `halt_code_o` | 13.673 | 8.516 | `dq_n[2]` |
| `u_alu.u_fpu.pow_n_r` | 13.672 | 6.654 | `u_alu.fb64_r[52]` |
| `u_alu.u_fpu.u_div.u_div.steps_r` | 13.635 | 7.759 | `u_alu.fb64_r[52]` |
| `u_alu.u_fpu.u_div.u_div.rem_r` | 13.635 | 7.759 | `u_alu.fb64_r[52]` |
| `u_alu.u_fpu.u_div.u_div.q_r` | 13.635 | 7.759 | `u_alu.fb64_r[52]` |

### `mpy_core`, the 12 worst groups after

| Register group | Before | After | Start of the worst path (after) |
| --- | ---: | ---: | --- |
| `st` | 15.458 | 10.332 | `sp[1]` |
| `m_addr` | 11.878 | 10.060 | `c_ndef[0]` |
| `u_alu.u_fpu.fd_floor_r` | 9.959 | 9.959 | `u_alu.u_fpu.t1_r[52]` |
| `u_alu.u_fpu.u_add.s1_shift_r` | 11.947 | 9.950 | `u_alu.u_fpu.state_r[0]` |
| `wb_v[0]` | 9.889 | 9.889 | `st[4]` |
| `alu_res` | 12.365 | 9.878 | `u_alu.op[0]` |
| `m_req` | 12.719 | 9.865 | `sp[1]` |
| `x0` | 9.464 | 9.564 | `ha_mdarg[1]` |
| `wb_v[3]` | 9.552 | 9.552 | `st[4]` |
| `wb_v[2]` | 9.494 | 9.494 | `st[4]` |
| `wb_v[1]` | 9.494 | 9.494 | `st[4]` |
| `u_alu.u_fpu.u_div.s1_exp_a_r` | 14.012 | 9.473 | `u_alu.u_fpu.state_r[0]` |

### `mpy_soc`, the 12 worst groups before

| Register group | Before | After | Start of the worst path (before) |
| --- | ---: | ---: | --- |
| `u_ca.copy_engine.rpend` | 16.105 | 10.009 | `c_pend` |
| `u_ca.copy_engine.req_o` | 15.724 | 9.662 | `c_pend` |
| `u_core.pc` | 15.689 | 9.207 | `u_core.dq_n[2]` |
| `u_ca.copy_engine.ra` | 15.613 | 9.518 | `c_pend` |
| `u_ca.bulk_engine.engine.req_o` | 15.484 | 10.198 | `c_pend` |
| `u_ca.copy_engine.rq_we` | 15.471 | 9.410 | `c_pend` |
| `u_ca.copy_engine.addr_o` | 15.471 | 9.410 | `c_pend` |
| `u_core.st` | 15.458 | 10.332 | `u_core.dq_n[2]` |
| `u_ca.copy_engine.rn` | 15.333 | 9.237 | `c_pend` |
| `u_ca.copy_engine.fc` | 15.329 | 10.043 | `c_pend` |
| `u_ca.copy_engine.wa` | 15.019 | 9.734 | `c_pend` |
| `u_ca.short_engine.issued` | 15.016 | 9.731 | `c_pend` |

### `mpy_soc`, the 12 worst groups after

| Register group | Before | After | Start of the worst path (after) |
| --- | ---: | ---: | --- |
| `u_core.st` | 15.458 | 10.332 | `trace_sp_o[1]` |
| `u_ca.bulk_engine.engine.req_o` | 15.484 | 10.198 | `u_ca.byte_engine.state[0]` |
| `u_ca.copy_engine.fc` | 15.329 | 10.043 | `u_ca.byte_engine.state[0]` |
| `u_ca.copy_engine.rpend` | 16.105 | 10.009 | `u_ca.byte_engine.state[0]` |
| `c_addr` | 11.951 | 9.986 | `u_core.c_ndef[0]` |
| `u_ca.bulk_engine.engine.addr_o` | 10.324 | 9.980 | `u_ca.bulk_engine.engine.op[1]` |
| `u_core.u_alu.u_fpu.u_add.s1_shift_r` | 11.947 | 9.969 | `u_core.u_alu.u_fpu.state_r[0]` |
| `u_core.u_alu.u_fpu.fd_floor_r` | 9.959 | 9.959 | `u_core.u_alu.u_fpu.t1_r[52]` |
| `u_ca.byte_engine.sa` | 9.947 | 9.947 | `u_ca.byte_engine.dest[1]` |
| `u_ca.byte_engine.da` | 9.947 | 9.947 | `u_ca.byte_engine.dest[1]` |
| `u_core.wb_v[0]` | 9.889 | 9.889 | `u_core.st[4]` |
| `u_core.alu_res` | 12.365 | 9.878 | `u_core.u_alu.op[0]` |

### Groups that got slower by more than 0.1 ns

| Group (`mpy_soc`) | Before | After |
| --- | ---: | ---: |
| `u_core.u_alu.u_fpu.res_r` | 4.341 | 5.935 |
| `u_core.scr_id` | 5.785 | 7.074 |
| `u_core.wfault_code` | 1.885 | 2.803 |
| `u_core.wfault_addr` | 1.885 | 2.803 |
| `u_core.wf_r` | 1.456 | 1.998 |
| `u_core.wpend` | 2.240 | 2.782 |
| `u_core.stack_base` | 6.361 | 6.619 |
| `u_core.cv_fun_g` | 8.168 | 8.413 |
| `u_core.u_alu.u_fpu.u_pow.j_r` | 3.025 | 3.233 |
| `u_core.u_alu.u_fpu.u_pow.cpos_r` | 7.692 | 7.900 |
| `u_core.u_alu.u_fpu.u_pow.cneg_r` | 7.684 | 7.892 |
| `u_core.u_alu.u_fpu.u_pow.state_r` | 3.482 | 3.690 |
| `u_core.u_alu.u_fpu.u_pow.i_r` | 2.934 | 3.142 |
| `u_ca.bulk_engine.shared_hash.part_r` | 4.401 | 4.559 |
| `u_core.stk_from` | 7.074 | 7.222 |

All are 2.3 ns or more inside the new critical path. `res_r` and `scr_id`
are new loads on existing nets (the pow pack's two-step result, the decode
clearing `scr_id`). The 15 frame-register groups and `u_boot.cst` named in
`planning/rv_io_core_progress.md` are unchanged from `1b44d1e` (6.24 and
5.19 ns): about 4 ns inside the critical path, so they were left alone.

## What changed for the clock

Each line is a path family that set or neared the period, the change, and
its cycle cost. "Proven" means a SAT miter (`miter -equiv`, Yosys) against
the old logic for all inputs; "checked" means a simulation assertion that
compares a registered value with the direct form wherever it is used, in a
build with `+define+MPY_CHECK` (off by default: the checks made the model
slower), run on the areas that use it.

| Path (before) | Change | Cycle cost |
| --- | --- | --- |
| decoder `dq_n` → `d_len`/`d_trunc` → `pc`, `st` (15.69) | flat length decode: continuation bits pick the byte count one-hot, the argument is an AND-OR of the 7 widths, truncation is one compare (proven) | 0 |
| FPU accept: `is_integer`, the power special cases, `b_trunc_abs` in front of every unit's start (14.6) | `dec_direct` from the opcode and `b_zero` only; `pow_n_small` a compare against a constant; float `**` decodes in `S_POW_DEC` from registered exponent flags | +1 per float `**` (+2 for its special cases) |
| pow pack: bias add, denormalize and round in one cycle (14.5) | `S_PACK` denormalizes, `S_PACK2` rounds (the split `upycore_f64_denorm` / `upycore_f64_round_pack`, already proven equal) | +1 per float `**` via 2^(y log x) |
| divider/power normalize through `upycore_clz64` (14.0) | `upycore_clz64` as a 6-level tree, one vector per level (proven; an in-place array version was correct but made the Verilator model 2.5× slower) | 0 |
| `sA` → `al_n` (13.7): `next_alloc` in front of the allocation | the size lookup in its own state `S_RH_LKD`; the table select an OR per bit | +1 per dict/set rehash |
| `hh` → `u_hmod` (13.6): 32-step clz on accept | clz by halving (proven) | 0 |
| `nexc`/`nloc` sums → frame top, spill check, call bound (13.2) | `fgeo_r` (17 + n_state + 3·n_exc) registered (checked); callee geometry `c_geo_r`; generator image geometry in `S_GR6`→`S_GR6B`; the frame bound as registered room `hp_free_r` and a 13-bit compare (checked) | +1 per generator resume |
| core request → copy-engine grant (16.1) | flat `mpy_mem` arbitration; flat scoreboard ORs in `mpy_ca`, `mpy_collection`, `mpy_shortlist`; flat no-fault decode with index-wide bounds and bit-select word indices (checked against `p_fault`); fetch request's region from the queue base flop | a lower port's faulting request for the same block makes a port wait one cycle (faults only) |
| fetch `redirect` → `fe_avail` → `st` (14.4) | `go_next` and `S_FETCH` always go to `S_DEC`; with nothing queued `S_DEC` returns | +1 only while the word at pc is still in flight |
| ALU float narrowing: sticky shift + round + select (11.6) | subnormal binary32 results take `A_FNAR2` (shift registered) | +1 per subnormal float result |
| ALU float `**` domain check in the dispatch (11.4) | `A_FERR` from operand flops | +1 per float `**` |
| ALU `F2I`: shift and negate (11.0) | magnitude, then sign in `A_F2I` | +1 per float→int |
| ALU widen: 22-step priority select (10.2) | the shared clz tree | 0 |
| string compare mask: subtract, shift, subtract (12.2) | mask registered in `S_SEA` | 0 |
| bytes compare: byte difference in the compare state | `S_N_BCC` | +1 per differing `bytes` compare |
| shared hash, float key: shift and negate (11.8) | two-step float hash (as the complex parts) | +2 per float dict key (bulk engine) |
| key-equal descriptor: subtract and add (10.3) | `qext − 8·qcount` at accept; `STR_PTR` adds 4 to the registered descriptor | 0 |
| call/`YIELD_FROM`/deref: ring reads and arg sums in `S_EXEC` (12.0–11.1) | one-byte LOAD/STORE_FAST take the cache hit/way from the opcode in `S_DEC`; 0x24–0x29, `CALL_FUNCTION(_VAR_KW)`/`CALL_METHOD` and `YIELD_FROM` spend one cycle in `S_EXEC_W` computing the hit, the call's fit/ring/size flags and the yield fast test from flops (checked) | +1 per call, per `YIELD_FROM`, per extended-local or deref access |
| `BUILD_LIST` stack hit (10.7) | `bl_base` registered; resident test `arg − gi ≤ resident_reals` (checked) | 0 |
| `S_UR_SLOW` depth compare (12.2) | its own cycle | +1 per unwind step (exception path) |
| spilled-stack read address (10.3) | word offset in `S_SRD_T1`, address in `S_SRD_T2` | +1 per value read from a spilled chunk |
| exception entry address (10.1) | `xb_r` (fbase + 0x44 + 4·nloc) registered, entry+word one narrow add (checked) | 0 |
| native argument count (10.7) | `nargs_r` registered (checked) | 0 |
| `S_BIN` operand classes (10.4) | `bin_num_r`, `bin_cx_r` set in `S_EXEC` (checked) | 0 |
| FP adder/denorm masks `(1 << sh) − 1` (11.6) | thermometer compares | 0 |

Net: the extra states cost less than the two cycle changes save, on every
kernel measured; the call and float-power costs are visible as the small
spread in the table (`bm_fannkuch` −7.9 % is the smallest cycle gain).

## Verification (this tree)

- Hardware suite, every area, `mpy-cross` and `--compiler mpyc`: all pass
  (548 + 548; `compile_reject_locals` alone is 75 min). Run per area by
  `build/run_suite.sh` (not committed) so a container restart loses one
  area at most.
- Unit benches: 37 of 37 (`mpy_numeric` 162,299 checks; its bench feeds the
  narrowing unit's new `jam_o` back to `jam_i`).
- Outputs: every hardware test against its golden; the 16 kernels'
  results equal the baseline's; `clock_bench` outputs identical. Goldens
  were not changed, so `make check-goldens` is unaffected.
- SAT proofs: decoder, `upycore_clz64`, `upycore_umod_seq` clz.

## After merging `main` (`4bb97a7`)

`main` had gained "Keep resumed generator locals in their SRAM image"
(`d0c6e20`), which registers the frame's stack prefix itself
(`stack_prefix_words`). The merge keeps that register in place of this
round's `fgeo_r`, and the frame-bound registers use it. The merged netlist
first moved `sp` → `m_req` to 10.66 ns (estimate). Two more changes bring it
back down: `stk_hit` is now a subtract and a 7-bit compare against the
resident count (SAT-proven equal while the depth cannot wrap 16 bits), and
the wide-call copy loop tests residency by count (checked under
`MPY_CHECK`).

| | Branch | Merged |
| --- | ---: | ---: |
| `mpy_core` worst path (estimate) | 10.332 ns | 10.314 ns |
| `mpy_soc` worst path (estimate) | 10.332 ns | 10.332 ns |

Kernels on the merged tree, against `1b44d1e` at 16.105 → 10.332 ns:

| Benchmark | Cycles before | Cycles merged | Cycles | Time ratio | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `bm_chaos` | 3,952,735 | 3,415,375 | -13.59 % | 0.554 | same |
| `bm_fannkuch` | 1,088,988 | 1,003,198 | -7.88 % | 0.591 | same |
| `bm_fft` | 10,293,659 | 9,403,405 | -8.65 % | 0.586 | same |
| `bm_float` | 3,292,939 | 2,884,645 | -12.40 % | 0.562 | same |
| `bm_hexiom` | 11,580,088 | 9,999,797 | -13.65 % | 0.554 | same |
| `bm_nqueens` | 13,953,480 | 11,891,961 | -14.77 % | 0.547 | same |
| `bm_wordcount` | 7,774,990 | 6,604,660 | -15.05 % | 0.545 | same |
| `core_locals` | 6,167,342 | 4,900,777 | -20.54 % | 0.510 | same |
| `core_qstr` | 78,850 | 61,539 | -21.95 % | 0.501 | same |
| `core_str` | 6,973,563 | 5,944,789 | -14.75 % | 0.547 | same |
| `core_yield_from` | 4,449,947 | 3,210,984 | -27.84 % | 0.463 | same |
| `misc_aes` | 1,510,327 | 1,370,947 | -9.23 % | 0.582 | same |
| `misc_mandel` | 5,390,732 | 4,948,750 | -8.20 % | 0.589 | same |
| `misc_pystone` | 3,496,801 | 2,946,340 | -15.74 % | 0.541 | same |
| `misc_raytrace` | 6,533,393 | 5,666,797 | -13.26 % | 0.556 | same |
| `bm_pidigits` | 1,510,982 | 1,383,642 | -8.43 % | 0.587 | same |

Geometric mean over 16: cycles x0.857, time x0.550 (1.82x faster); worst time ratio 0.591.

`core_yield_from` gains most from `main`'s change (−27.8 % cycles instead
of −9.5 %).

Verification of the merged tree: hardware suite 549 of 549 with
`mpy-cross` and 549 of 549 with `--compiler mpyc` (the new
`gen_resumed_local_gc` included); unit benches 37 of 37; checking build
(`+define+MPY_CHECK`) clean on the generators, exceptions, calls and
containers areas.

## Hardware suite run time

The `compiler` area runs the uPy2 compiler as bytecode on the simulated
hart. Its programs are 15 to 420 million cycles each, and the model runs
at roughly 100 to 200 thousand cycles a second. `compile_reject_locals`
alone is 423 million cycles, 27 % of the area, and it started last. The
`mpyc` pass then repeated the whole area, although uPy2 links the same
bytes as `mpy-cross` for all 548 programs. `hw_tests.py` now reuses an
identical run (same simulator, image and plusargs) and starts the longest
tests first, and the model is compiled at `-O2`. The whole suite with both
compilers took 74 minutes at `-j 4` (4,403 s for `mpy-cross`, 34 s for
`mpyc`), against about five hours before.

## Not verified

- Genus / Innovus timing of any kind; all periods are estimates.
- The `--mapped` flow (noisy, not gated on).
- CI and the Docker image (Debian Verilator 5.032); this used 5.038.
- `converted/` was not regenerated for the backend.

## Left for the next round

`st` ← `sp` (10.33: the `S_BIN` and call dispatch's ring reads), the map
engine's request ← the byte engine's state through `mpy_mem` (10.20),
`m_addr`/`c_addr` ← `c_ndef` (10.06: the default-argument address), and the
9.9–10.0 ns cluster (`u_add.s1_shift_r`, `fd_floor_r`, `byte_engine.sa/da`,
`wb_v`, `alu_res`).
