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

### 7. Hash memo for image qstrs (cycles) — landed

- Sink: every qstr-keyed lookup loads the qstr's descriptor word from the
  image for its 16-bit hash (`S_HASH` -> `S_QD` -> `S_HASH_W16`), about 6.5
  cycles; almost every traced key is a qstr.
- Change (`mpy_core.sv`): 64 direct-mapped entries {id[12:6], hash[15:0]},
  indexed by id[5:0], filled in `S_HASH_W16` for ids below `h_nq` and
  below 8192. `S_LK_TB` takes the hash from a hit and goes to `S_LK_H`
  with the registers `S_HASH` would have left. The image is read-only
  (`MPY_FAULT_FLASH_STORE`) and `S_BOOT` runs only out of reset, so an
  entry never goes stale. Run-time qstrs are never entered. Traced hit
  rate of this shape: 85 to 96 %.
- Not chosen: a memo of the probe position or of the found slot. Tables
  are rewritten and reused, so it needs invalidation the core does not
  have.
- Cycles: geomean 0.9086 of baseline (cumulative), results identical
  (`build/kern/k4-qmemo`).
- Proof: `+define+MPY_CHECK` at each fill: a valid entry with the same tag
  must hold the hash just read, and the descriptor must be in the image.
- Cost: 64 x 24 flops. Timing gated in the SoC STA of change 8.

### 8. The probe's own registers, not a scratch image (cycles) — landed

- Sink: `S_SCR` is 4.2 % of cycles plus its waits. A lookup under an
  attribute load stored the caller's image (8 stores), ran, and the
  caller then stored the dead probe image (8 stores) and reloaded its own
  (8 loads).
- Change (`mpy_core.sv`): the probe's six words are `lkA[0:5]`, not
  `sA[0:5]`. `lookup` is a plain `gosub`; `S_LK` has no adopt cycle and
  `S_LK_KE` no reload. The grow (`S_RH`), called only from the probe and
  ending by restarting it at `S_LK`, sizes and fills the new table in
  `lkA[0]` / `lkA[1]`; its read of the stored probe image and the two
  writes back (dead: `S_LK` reads alloc and table again) are gone, with
  the states `S_RH_LKA`, `S_RH_LKB`, `S_RH_F3`, `S_RH_F3B`. `S_LK` is not
  entered while a probe is live (`S_KEYEQ`, `S_HASH`, `S_RH` look nothing
  up) and no probe is live across `S_DEC`. The probe has no tagged word,
  so the collector's roots do not change.
- Cycles: geomean **0.8589** of baseline (changes 4 to 8), every `RESULT`
  identical to the baseline executable (`build/kern/k5-lkreg`).
  `bm_chaos` 3415313 -> 2787850; `bm_wordcount` 6604660 -> 4287344; `core_locals` 4900777 -> 3740237; `misc_pystone` 2946340 -> 2436995; `misc_raytrace` 5666797 -> 4566080.
- Cost: 192 flops. The LK slot of the scratch reservation is unused; the
  memory map is unchanged.
- SoC STA with changes 1, 3 to 8 (`build/sta/k5-lkreg-soc/sta.txt`): worst
  10.332 -> 10.295 (`u_core.st`). No listed group grew by more than
  0.1 ns; `c_addr` 9.986 -> 9.946. The state encoding moved (four states
  fewer), which is where the 0.04 ns comes from; it is not a cut.
- Gate: geomean of cycles x period = 0.8589 x 10.295 / 10.332 = 0.856.

### 9. S_EXEC op class (family A, `st`) — landed

- Path: `sp` -> register-file read -> the arms of `case (op)` in `S_EXEC`
  -> six selects in series (the op-range `if / else` chain in front of the
  case) -> state case -> `st`, 10.332 ns in the baseline, the worst path.
- Change (`mpy_core.sv`): `xcls`, a seven-value class decoded from `op`
  alone by the same chain; `S_EXEC` is `case (xcls)` with the old
  `case (op)` as its default arm. Every arm's value now passes one select.
- Proof: SAT miter of the old chain's branch choice against `xcls` over
  every `op` (`build/proof/xcls.ys`): passed.
- STA: `mpy_core` alone with this change, `build/sta/p1-xcls-core/sta.txt`:
  worst 10.295 (`st`), now from `md` through the `S_RF_RELOAD_G` fit test
  (change 12). SoC STA of changes 9 to 18, `build/sta/p3-cuts-soc/sta.txt`:
  `u_core.st` 10.295 -> 9.995.
- Cycles: none (same branch for every op).

### 10. `x2` in the call setup (family C) — landed

- Path: `rf` -> `has_link` -> `stk_depth` -> `- v2` -> `+ (1 or 2)` ->
  `x2`, 10.021 ns.
- Change (`mpy_core.sv`): `x2 <= stk_depth - (v0 + (v1 << 1))`. `v2` is
  `v0 + 2 * v1` plus that same 1 or 2, so the two adds behind `stk_depth`
  are one.
- Proof: SAT miter of the two expressions over `stk_depth`, `v0`, `v1`
  and the op bit (`build/proof/core_arith.ys`): passed.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `u_core.x2` 10.021 -> 8.530.
- Cycles: none.

### 11. Default-argument address (family D, `c_addr`) — landed

- Path: `c_ndef` / `c_npos` -> `i0 - (npos - ndef)` -> `* 4` -> `+ defs + 4`
  -> `m_addr` (`c_addr` 9.986 ns in the baseline).
- Change (`mpy_core.sv`): `S_BF`, which every fast bind passes, registers
  `bf_db = adr(c_defs) + 4 - 4 * (c_npos - c_ndef)`; `S_BF_DEF` loads
  `bf_db + 4 * i0`. 32 flops.
- Proof: SAT miter of `bf_db + 4 * i0` against the old sum
  (`build/proof/core_arith.ys`): passed. The registered value is compared
  with the old expression in `S_BF_DEF` under `+define+MPY_CHECK`; the 16
  kernels ran clean with it.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `c_addr` 9.946 -> 9.339
  (with change 14).
- Cycles: none (`S_BF` already existed).

### 12. Reload fit test (family A, `st`) — landed

- Path: `md` -> chunk count -> `v2 = sp + count (+ link)` (32 bits) ->
  `v2 > MPY_RF_DEPTH` -> `st`, 10.295 ns: the worst path once change 9 is
  in.
- Change (`mpy_core.sv`, `S_RF_RELOAD_G`): the fit is tested on nine
  bits, `{2'b00, sp} + {1'b0, count[7:0]}`, beside the range test of the
  count instead of behind a 32-bit sum.
- Proof: SAT miter of the old and new branch condition over `md`, `sp`
  and the link bit (`build/proof/reload_fit.ys`): passed. `MPY_CHECK`
  compares the two in every `S_RF_RELOAD_G`.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `u_core.st` 10.295 -> 9.995,
  now from `alu_res` in `S_BI_DIV_CHECK` (change 19).
- Cycles: none.

### 13. `rf_icpt` state test (family H, `wb_v`) — landed

- Path: `st` -> fifteen `st != X &&` terms in series -> `rf_icpt` -> the
  enable of every register the microcode writes; `wb_v[0]` 9.889 ns.
- Change (`mpy_core.sv`): the fifteen excepted states are one `case`, so
  their compares meet in a tree.
- Proof: SAT miter of the old and new `rf_icpt` over `st` and `rf_pend`
  (`build/proof/rf_icpt.ys`): passed.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `u_core.wb_v[0]` 9.889 ->
  9.743, `wb_v[3]` 9.552 -> 9.406; `u_core.rf` 8.948 -> 8.682 in the same
  run.
- Cycles: none.

### 14. Next slot of a delete (family D, `c_addr`) — landed

- Path: `lkA` (position, alloc) -> `pos + 1 == alloc` -> select -> shift
  -> `+ table` -> `m_addr`, about 9.9 ns after change 8 (`c_addr` 9.946
  in `build/sta/k5-lkreg-soc/sta.txt`).
- Change (`mpy_core.sv`, `S_LK_RM`): the address is `lk_nwrap ? table :
  slot + 4 or 8`, the look-ahead that change 6 already keeps for the slot
  being removed.
- Proof: registered form. `MPY_CHECK` compares it with the old sum in
  every `S_LK_RM`; hardware area `containers` (dict and set deletes).
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `c_addr` 9.946 -> 9.339.
- Cycles: none.

### 15. Map engine ERASE address (family E) — landed

- Path: `op` -> slot select -> `+ 1` -> `== dn` -> wrap select -> shift ->
  `+ dst` -> `addr_o`, 9.980 ns.
- Change (`mpy_map_engine.sv`): `slot + 1 == dn ? dst : at(dst, slot + 1)`:
  the compare selects between the table base and the summed address
  instead of standing in front of the add.
- Proof: SAT miter of the two address expressions over `op`, `idx`,
  `pos`, `dn`, `dst`, `is_set` (`build/proof/erase_addr.ys`): passed. Unit
  benches `mpy_map_engine`, `mpy_map_cache`, `mpy_bulk`, `mpy_collection`,
  `mpy_rehash_stream` pass.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`):
  `bulk_engine.engine.addr_o` 9.980 -> 9.329.
- Cycles: none.
