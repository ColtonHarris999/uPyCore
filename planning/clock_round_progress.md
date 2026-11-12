# Clock round progress

Score: execution time on the 16 paper kernels, cycles x open-flow period.
Period: worst reg-to-reg group in `mpy_soc` `sta.txt` from
`python3 upycore/tools/sta/run.py mpy_soc --lib "$SKY130_LIB" --no-fsm`
(unmapped, sky130 typical, yowasp-yosys 0.70). It is a number to compare
against the same command on the pre-change RTL. It is not a Genus number and
not a post-route period.

## Baseline (main at a09ca4f)

| item | value | from |
|---|---|---|
| `mpy_core` worst | 10.314 ns (`st[1]`) | `build/sta/base-core/sta.txt` |
| `mpy_soc` worst | 10.332 ns (`u_core.st[1]`) | `build/sta/base-soc/sta.txt` |
| simulator | sha256 `fcf88efa...1308d0e` | `build/sta/base-soc/Vtb_mpy_soc` |

Kernel cycles (N=100 M=100, `+CA=1 +AALU=1`), all results OK:

| kernel | cycles |
|---|---|
| bm_chaos | 3415313 |
| bm_fannkuch | 1003198 |
| bm_fft | 9403387 |
| bm_float | 2884645 |
| bm_hexiom | 9999798 |
| bm_nqueens | 11891921 |
| bm_wordcount | 6604660 |
| core_locals | 4900777 |
| core_qstr | 61539 |
| core_str | 5944651 |
| core_yield_from | 3210984 |
| misc_aes | 1370947 |
| misc_mandel | 4948750 |
| misc_pystone | 2946340 |
| misc_raytrace | 5666797 |
| bm_pidigits (bigint oracle) | 1383634 |

Path families at or above 9.5 ns in the baseline `mpy_soc` report
(traced with `TRACE=... TRACE_SRC=1` on the saved netlist):

| family | groups | ns | path |
|---|---|---|---|
| A | `u_core.st` | 10.332 | `sp` -> `sp-1` -> ring read -> op 0x30 tag test -> `case (op)` -> S_EXEC op-range chain -> state case -> wrapper mux |
| B | `u_ca.bulk_engine.engine.req_o`, `copy_engine.fc/rpend/wa/cnt/req_o/qv/wn/ra`, `short_engine.issued` | 10.198 .. 9.518 | `byte_engine.state` -> `by_addr` select -> `am_addr` mux -> `mpy_mem` bound compare -> `am_gnt` -> engine |
| C | `u_core.x2`, `c_req`, `u_core.cv_fun_g` | 10.021, 9.578, 9.390 | `rf` -> `has_link` -> `stk_depth` -> add / `stk_hit` |
| D | `c_addr` | 9.986 | `c_ndef` -> `S_BF_DEF` address expression (two adds) -> state case |
| E | `bulk_engine.engine.addr_o` | 9.980 | map engine `ERASE`: `+1`, compare with `dn`, shift, add |
| F | `u_fpu.fd_floor_r`, `u_fpu.u_add.s1_shift_r`, `u_div.s1_exp_a_r` | 9.959, 9.950, 9.473 | FPU floor; add stage 1 operand select -> clz -> shift |
| G | `byte_engine.sa`, `byte_engine.da` | 9.947 | `SETUP`: room compare -> 32-bit `remaining <` -> 32-bit subtract |
| H | `u_core.wb_v[0..4]` | 9.889 .. 9.286 | `st` -> `rf_icpt` AND chain -> wrapper -> serial write-enable ORs |
| I | `u_core.alu_res` | 9.878 | 64-bit subtract in `upycore_int_alu` -> result mux |
| J | `bulk_engine.shared_hash.state/result` | 9.649, 9.511 | hash byte count add -> compare -> state |
| K | `u_core.x0` | 9.564 | `S_SRD_T1` address expression -> add |
| wall | `u_hmod.*`, three `modulo.*` | 9.366 | sequential modulo: two compare-subtract steps per cycle |

## Attempts

Periods are copied from `sta.txt` of the run named in each entry. "SoC STA"
is `python3 upycore/tools/sta/run.py mpy_soc --lib "$SKY130_LIB" --no-fsm`,
compared with `--compare build/sta/base-soc/sta.txt`.

### 1. Memory grant without the fault decode (family B) — landed, 5d5b218

- Path: `byte_engine.state` -> `by_addr` -> `am_addr` -> `mpy_mem` bound
  compare (`p_mem`) -> `am_gnt` -> every collection engine, 10.198 ns at
  `bulk_engine.engine.req_o`.
- Change (`mpy_mem.sv`): `gnt_o[p] = req_i[p] && ready[p] && !lost`. It was
  `&& (!p_mem[p] || !lost)`, which put the address decode in front of the
  grant only so that a request that is going to fault is granted while its
  block index is in use.
- SoC STA (`build/sta/c1-memgnt-soc/sta.txt`): worst 10.332 -> 10.332
  (`u_core.st`, not this family). `bulk_engine.engine.req_o` 10.198 -> 9.578,
  `copy_engine.fc` 10.043 -> 9.423, `copy_engine.rpend` 10.009 -> 9.389. No
  group grew.
- Cycles: a request that faults now waits while another port holds its block
  index. Nothing else changes; the 16 kernels fault nowhere.
- Proof: not equivalent by design. Unit benches `mpy_shared_mem mpy_ca
  mpy_fetch mpy_value mpy_gc` pass (5 of 5).
- Landed on the STA compare alone: it shortens paths that are not the worst
  one and adds no cycles to a run that does not fault.

### 2. Byte engine address select from a flop (family B) — not landed

- Path: the same, from its start: `byte_engine.state` decode -> `by_addr`.
- Change tried (`mpy_bytecopy.sv`): a flop `addr_src` set with the state in
  place of the state decode in `addr_o`. Inductive SAT proof that the flop
  equals the decode passed (`sat -tempinduct`), with a negative control.
- SoC STA (`build/sta/c2-byaddr-soc/sta.txt`, on top of change 1): worst
  10.332; `bulk_engine.engine.req_o` 9.578 -> 9.578, `copy_engine.fc` 9.423
  -> 9.423. After change 1 the family starts at `c_pend`, not at the byte
  engine's state, so the flop buys nothing.
- Not landed: no group got shorter. Removed from the tree.

### 3. Byte engine `next_n` clamp on three bits (family G) — landed

- Path: `dest` -> `dst_room` -> `next_n` select -> 32-bit `remaining <
  next_n` -> `next_n` -> 32-bit subtract -> `sa` / `da`, 9.947 ns.
- Change (`mpy_bytecopy.sv`): `remaining[31:3]==0 && remaining[2:0]<next_n`
  in place of `remaining<32'(next_n)`. `next_n` is at most 4.
- Proof: SAT miter of the old and new `next_n` over every `remaining`,
  `src_room`, `dst_room` (`miter -equiv`, `sat -verify -prove trigger 0`):
  passed.
- SoC STA (`build/sta/c3-bynextn-soc/sta.txt`; the run also had change 2 in
  the tree, which touches only `addr_o`): worst 10.332 -> 10.332;
  `byte_engine.sa` and `.da` 9.947 -> 9.130. No group grew.
- Cycles: none (equivalent logic).
- Unit benches `mpy_bytecopy`, `mpy_collection` pass.
- Landed on the STA compare alone.

### 4. A find skips the dict flags word (cycles) — landed

- Sink: the profile's top opcode is `LOAD_GLOBAL` (25.5 % of cycles, 65.9
  cycles each), up to three dict probes; `S_LK*` and its memory waits lead
  the state table.
- Change (`mpy_core.sv`, `S_LK`): a find reads the alloc word first. The
  flags word (ROM bit) is only tested by a store or a delete; a find read
  it and ignored it. One load (about 3.7 cycles) less per lookup.
- Cycles: geomean of the 16 kernels 0.9816 of baseline at an unchanged
  period; every `RESULT` matches the baseline executable
  (`build/kern/k1-lkfind`). `bm_wordcount` 6604660 -> 6547503; `core_locals` 4900777 -> 4759162; `core_qstr` 61539 -> 59121.
- Proof: not an equivalence (the load is gone). Kernel results, and the
  hardware suite at the end of the round.
- Timing: gated with changes 5 to 8 in one SoC STA, see change 8.

### 5. Power-of-two tables take the probe start by mask (cycles) — landed

- Sink: `S_LK_HM`, the sequential `hh % alloc`, 3.3 % of cycles. Traced
  table sizes are {2, 4, 6, 8, 10, 12, 17, 23, ...}.
- Change (`mpy_core.sv`, `S_LK_H`): when `alloc & (alloc - 1)` is 0 the
  start is `hh & (alloc - 1)`, without the divider. `alloc` is not 0 here.
- Cycles: geomean 0.9730 of baseline (cumulative with change 4), results
  identical (`build/kern/k2-pow2`).
- Proof: `x % 2^k == x & (2^k - 1)` for unsigned x; kernel results.
- Timing: `lk_am1` / `lk_pow2` hang off the alloc register. Gated in the
  SoC STA of change 8.

### 6. Probe look-ahead (cycles) — landed

- Sink: each further probe went `S_LK_K` -> `S_LK_NX` (next position, wrap,
  end test) -> `S_LK_P` (slot address, load): two cycles around every key
  load. Traced lookups take 2.0 to 5.1 probes.
- Change (`mpy_core.sv`): `S_LK_P` registers the next position, whether it
  wraps and whether it ends the probe (`lk_npos`, `lk_nwrap`, `lk_nend`).
  On a tombstone or a different qstr / int key `S_LK_K` issues the next
  key load itself (`lk_next`): the slot address is the old one plus 4 or 8,
  or the table base on a wrap. The last slot still goes through `S_LK_NX`.
- Cycles: geomean 0.9403 of baseline (cumulative), results identical
  (`build/kern/k3-probe`).
- Proof: registered form, checked in simulation: `+define+MPY_CHECK`
  compares slot, next position, wrap and end against the unregistered
  expressions in every `S_LK_K` (no error on `misc_pystone`,
  `misc_raytrace`; the whole kernel set under MPY_CHECK is in change 8).
- Timing: gated in the SoC STA of change 8.
