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

### 16. FP floor mask and alignment shift (family F) — landed

- Paths: `state_r` -> operand select -> exponent -> `(1 << nfrac) - 1` ->
  `fd_floor_r`, 9.959 ns; exponent difference -> `> 55` compare -> clamp ->
  `s1_shift_r`, 9.950 ns.
- Change: `frac_mask = ~(all-ones << nfrac)` (`upycore_fp_defs.svh`), a
  shift without the 52-bit decrement; the clamp test is
  `|diff[10:6] || &diff[5:3]` (`upycore_fp_add.sv`), which is `diff > 55`.
- Proof: SAT miters of both pairs (`build/proof/fp_cuts.ys`): passed. Unit
  benches `mpy_alu`, `mpy_numeric`, `upycore_fp_subnormal` pass.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `fd_floor_r` 9.959 -> 7.267;
  `u_add.s1_shift_r` 9.950 -> 9.203.
- Cycles: none.

### 17. Integer unit op code (family I, `alu_res`) — landed

- Path: `u_alu.st` / `op` -> `case (op)` -> `iop` -> integer unit (64-bit
  subtract) -> `res_o` -> `alu_res`, 9.878 ns.
- Change (`mpy_alu.sv`): `iop` is a register, written with `iop_of(...)`
  wherever `op` is written (accept, and the two ABS rewrites). 5 flops.
- Proof: SAT, two parts (`build/proof/alu_iop.ys`, `alu_iop_base.ys`):
  `iop == iop_of(op)` is kept by one clock from any state where it holds,
  and holds out of reset. A wrong `iop_of` in the wrapper makes the proof
  fail (`alu_iop_bad.ys`). `MPY_CHECK` asserts the same every clock. Unit
  benches `mpy_alu`, `mpy_numeric` pass.
- SoC STA (`build/sta/p3-cuts-soc/sta.txt`): `u_core.alu_res` 9.878 ->
  9.165.
- New group: the tool reads the `iop_of` table in front of a register of
  its own, `$auto$proc_rom.cc:154:do_switch$1`, 9.185 ns from `sp` through
  the `alu_op` select (`alu_op` itself is 7.5 ns). It is not in the
  baseline list and it is below the worst path.
- Cycles: none.

### 18. String hash byte count (family J) — landed

- Path: `ptr` -> bytes left in the word -> `len < count` (32 bits) ->
  `count` -> byte hash chain -> `len == count` -> `state` / `result`,
  9.649 / 9.511 ns.
- Change (`mpy_hash.sv`): `count` is at most 4, so the clamp is
  `len[31:3] == 0 && len[2:0] < count`, and the last-word test is
  `len[31:3] == 0 && len[2:0] <= count` taken before the clamp.
- Proof: SAT miters of the old and new `count` and last-word flag for
  BYTES_PER_CYCLE 1 and 4 (`build/proof/hash_count1.ys`,
  `hash_count4.ys`): passed. Unit benches `mpy_hash`, `mpy_hash4`,
  `mpy_hash_slot`, `mpy_hash_slot4` pass.
- SoC STA (`build/sta/p4-soc/sta.txt`): `shared_hash.state` 9.649 ->
  6.814, `shared_hash.result` 9.511 -> 7.222.
- Cycles: none.

### 19. Bigint division check (family A, `st`) — landed, one cycle

- Path: `alu_res` -> `bi_prefix - alu_res` (64 bits) -> `>= bi_q` -> `st`,
  9.995 ns: the worst path of the SoC STA of changes 9 to 18.
- Change (`mpy_core.sv`): `S_BI_DIV_CHECK` registers the remainder in
  `bi_prefix` (reloaded by every division before it is read) and
  `S_BI_DIV_CHECK2` compares it with the quotient.
- Cycles: one more per bigint `//`. `bm_pidigits` 1365834 -> 1366316
  (482 divisions); the other 15 kernels are unchanged
  (`build/kern/p4`). Results identical.
- Proof: not an equivalence (one more state). Kernel result of
  `bm_pidigits`; hardware area `numbers`.
- SoC STA (`build/sta/p4-soc/sta.txt`, changes 9 to 20): `u_core.st`
  9.995 -> 9.637, now from the fetch queue (change 21).

### 20. `wb_v` packed (family H) — landed

- Path: `st` -> `rf_icpt` -> write-enable of the `wb_v` memory -> a serial
  OR of its write ports -> write select -> `wb_v[0]`, 9.743 ns after
  change 13. The tool made the unpacked array a memory and merged its
  twenty writers in a chain.
- Change (`mpy_core.sv`): `val_t [0:7] wb_v`. Same words, same indexes.
- Proof: none needed beyond the language (same storage); kernels and the
  hardware suite.
- SoC STA (`build/sta/p4-soc/sta.txt`): the group is now listed under the
  tool's net name `$10547y`, 8.986 ns (it was `u_core.wb_v[0]` 9.889 in
  the baseline). `u_core.t` 8.842 -> 7.642.
- Cycles: none.

### 21. Fetch fault test in S_FETCH (family A, `st`) — landed

- Path: `u_fetch.qn` -> first faulted word -> `qb + 4 * vn` -> compare
  with `pc` -> the last arm of `S_FETCH`'s `if / else` chain (five selects)
  -> state case -> `st`, 9.637 ns: the worst path of the SoC STA of
  changes 9 to 20.
- Change (`mpy_core.sv`): the fault arm is tested first, and-ed with the
  inverse of the or of the arms that used to come before it (accelerator
  fault, spill, reload, soft point with an event). Same arm for every
  input.
- Proof: SAT miter of the old and new chain's arm choice over the six
  conditions (`build/proof/fetch_chain.ys`): passed.
- SoC STA (`build/sta/p5-soc/sta.txt`, changes 1 to 21 without 2): worst
  **9.578** (`bulk_engine.engine.req_o`, family B); `u_core.st` 9.637 ->
  9.453. Against the baseline over every group (not only the 60 listed):
  two new groups, the tool's `iop_of` table register 9.204 (change 17)
  and `wb_v` under its net name 8.986 (change 20); groups that grew by
  more than 0.1 ns, all far below the worst: `rf_resume` 6.361 -> 7.443,
  `rf_pend_v` 6.480 -> 7.321, `aalu_ret` 5.630 -> 7.305, `dq_bytes` and
  `d_op` 7.045 -> 7.266, `aux` 6.949 -> 7.160, `scr_gt` 6.986 -> 7.158,
  `at_q` 6.207 -> 7.010.
- Cycles: none. Kernels on this tree (`build/kern/p5`): see the summary.

### 22. Lookup loads as bursts (cycles) — landed

- Sink: after change 8 the profile's lookup states and their memory waits
  still lead: each single load is a request, about 2.7 cycles of wait and
  a cycle to use the word. A lookup made two in a row for its header
  (alloc word, table word), and a dict find that hits made two more in a
  row (key, then value).
- Change (`mpy_core.sv`): two bursts of two loads, in the style of the
  call-setup bursts (`S_CF_Q`): the second load is presented as soon as
  the first is taken and the acks are taken in order.
  `S_LK_B` (replaces `S_LK_AL`, `S_LK_TB`) reads alloc and table.
  `S_LK_PB`, for a dict find only, reads a slot's key and value; the key
  is compared in the cycle the value arrives, which is the cycle `S_LK_K`
  would have run, so a hit takes the value from the bus and a miss sends
  the next key load as before. A key that needs `S_KEYEQ` goes on through
  the old states and loads the value again. Sets, stores and deletes keep
  the single loads. Both states are in the `rf_icpt` exception list (they
  take acks). The value load is inside the table, so no new address is
  read.
- Cycles: geomean **0.8181** of baseline (was 0.8589), every `RESULT`
  identical (`build/kern/b1`). `bm_chaos` 2787850 -> 2610289; `bm_hexiom`
  8444132 -> 7970511; `core_locals` 3740237 -> 3465226; `misc_pystone`
  2436995 -> 2271211; `misc_raytrace` 4566080 -> 4230237.
- Proof: not an equivalence. `MPY_CHECK` checks the look-ahead and that
  the value load was sent in every `S_LK_PB` answer; the 16 kernels ran
  clean with it (`build/kern/b1-chk`).
- SoC STA (`build/sta/b1-soc/sta.txt`): worst 9.578, unchanged. Against
  change 21's run over every group: `core_hval` 8.113 -> 8.268; about a
  hundred `u_core` registers at 5.9 to 6.5 ns moved up by 0.19 ns (the
  state decode, `st[4]`); nothing above 8.3 ns grew.

### 23. Probe-start memo; the probe start is picked in `S_LK_B` (cycles) — landed

- Sink: in the profile of change 22's simulator `S_LK_HM`, the wait for
  `hash % alloc` on the sequential divider, is 3.6 % of all cycles (mean
  of ten kernels), and `S_LK_H` is one more cycle on every lookup.
- Change (`mpy_core.sv`): `hash % alloc` depends on its two operands
  only, so a remainder the divider produced is kept: 32 direct-mapped
  entries {hash[15:5], alloc[11:0], remainder[11:0]}, indexed by
  `hash[4:0] ^ alloc[4:0]`, filled in `S_LK_HM` when the hash fits 16 bits
  and alloc is below 4096 (1152 flops). No store ever makes an entry
  wrong, so there is no invalidation. The qstr hash of the key is
  registered in `S_LK` (`lk_hq`), so for a key whose hash comes from the
  qstr memo `S_LK_B` picks the probe start itself in the cycle the table
  word arrives (hash below alloc, power-of-two mask, memo hit, or start
  the divider): `S_LK_H` is skipped on that path.
- Cycles: geomean **0.7946** of baseline (was 0.8181), every `RESULT`
  identical (`build/kern/b2`). `core_locals` 3465226 -> 3185496;
  `misc_pystone` 2271211 -> 2157173; `bm_hexiom` 7970511 -> 7741409.
- Proof: not an equivalence. `MPY_CHECK` compares every memo hit with
  `lk_hq % alloc` and `lk_hq` with the qstr memo's hash; the 16 kernels
  ran clean with it (`build/kern/b5-chk`, the tree of change 25, where
  the check build keeps this memo live).
- SoC STA (`build/sta/b2-soc/sta.txt`): worst 9.578, unchanged; `st`
  9.472. Grew by more than 0.1 ns over change 22's run: `hm_start` 6.022
  -> 7.722, `lkA` 6.589 -> 6.950, `lk_hasav` 6.368 -> 6.633, `u_gc.zaddr`
  3.883 -> 4.003.

### 24. LOAD_NAME / LOAD_GLOBAL start the lookup in `S_QOP` (cycles) — landed

- Sink: opcode 0x12 (LOAD_GLOBAL) is 19 % of the cycles in the profile.
  `S_QOP` set a counter and went to `S_LN_L`, which only called
  `lookup()` on the dict the counter named.
- Change (`mpy_core.sv`): `S_QOP` calls `lookup()` on the first dict
  itself and `S_LN_R` calls it on the next one when the name is not
  found. `S_LN_L` is removed. One cycle less per dict tried.
- Cycles: geomean **0.7894** (was 0.7946), every `RESULT` identical
  (`build/kern/b3`). `core_locals` 3185496 -> 3149318; `misc_pystone`
  2157173 -> 2140658.
- Proof: unit bench and kernels, not a miter (the state is gone, so
  there is no cycle-for-cycle twin).
- SoC STA (`build/sta/b3-soc/sta.txt`): worst 9.578, unchanged; `st`
  9.446. Grew by more than 0.1 ns over change 23's run:
  `shared_hash.part_r` 4.439 -> 4.559, `u_gc.raddr` 3.773 -> 3.880.

### 25. Qstr-operand memo (cycles) — landed, second form

- Sink: every opcode with a qstr operand (LOAD_NAME, LOAD_GLOBAL,
  LOAD_ATTR, LOAD_METHOD, STORE_*, LOAD_CONST_STRING) first loads the
  word `qbase[arg]` of the module's qstr table: a request, the image's
  wait and a cycle.
- Change (`mpy_core.sv`): a table in the image cannot change (a store to
  the image faults), so its words are kept: 32 direct-mapped entries
  indexed by `arg[4:0]`, each {qbase, arg[15:5], id[15:0], tag} (1568
  flops), filled in `S_LCS` / `S_QOP` when the word just read is at
  `qbase + 4 * arg`, in the image, and its id fits 16 bits. A hit sets
  `md`, `mt`, `m_addr` and `wret` as the load would and goes to the next
  state. A table in SRAM is never entered.
- First form, not landed: the entry was tagged with the word address, so
  the hit waited for the `qbase + 4 * arg` adder: `u_core.st` became the
  worst path at **9.865 ns** (`build/sta/b4-soc/sta.txt`, `arg` ->
  `ha_qarg` -> `qa_hit` -> `st`). The tag is now the two operands, which
  are compared beside the adder.
- A 128-entry table was tried: `misc_pystone` 2101642 -> 2082438, not
  worth four times the flops.
- Cycles: geomean **0.7808** (was 0.7894), every `RESULT` identical
  (`build/kern/b5`). `core_qstr` 38192 -> 37388; `core_locals` 3149318 ->
  3113068; `misc_pystone` 2140658 -> 2101642.
- Proof: not an equivalence. With `MPY_CHECK` the load is always made
  and an entry with the same tag is compared with the word read; the 16
  kernels ran clean with it (`build/kern/b5-chk`).
- SoC STA (`build/sta/b5-soc/sta.txt`): worst 9.578, unchanged; `st`
  9.445. Grew by more than 0.1 ns over change 24's run: `md`, `mt`,
  `ha_mdarg` 6.123 -> 7.021; `shared_hash.tag` / `payload` 4.556 ->
  4.676; `u_gc.rescanning` 3.585 -> 3.687.

## Result (HEAD of this branch against main at a09ca4f)

| item | baseline | now | from |
|---|---|---|---|
| `mpy_soc` worst | 10.332 ns (`u_core.st`) | 9.578 ns (`u_ca.bulk_engine.engine.req_o`) | `build/sta/b5-soc/sta.txt` |
| `mpy_core` worst | 10.314 ns (`st`) | 9.532 ns (`x0`) | `build/sta/b5-core/sta.txt` |
| 16 kernels, cycles, geomean | 1 | 0.7808 | `build/kern/final` |
| 16 kernels, cycles x period, geomean | 1 | 0.7238 | same, 10.332 -> 9.578 |

Both periods are the open flow's (unmapped, `--no-fsm`, sky130 typical, no
wires). They compare this RTL with the baseline RTL under one command.
They are not Genus numbers and not post-route periods.

Kernels on `build/mpy_soc/obj/Vtb_mpy_soc` built from this tree against
`build/sta/base-soc/Vtb_mpy_soc`; time ratio is (cycles x 9.578) /
(cycles x 10.332); every `RESULT` is the baseline's:

| kernel | cycles before | cycles after | time ratio | result |
|---|---|---|---|---|
| bm_chaos | 3415313 | 2492581 | 0.6766 | same |
| bm_fannkuch | 1003198 | 1000755 | 0.9248 | same |
| bm_fft | 9403387 | 8156344 | 0.8041 | same |
| bm_float | 2884645 | 2202469 | 0.7078 | same |
| bm_hexiom | 9999798 | 7597945 | 0.7044 | same |
| bm_nqueens | 11891921 | 10030763 | 0.7819 | same |
| bm_pidigits | 1383634 | 1342992 | 0.8998 | same |
| bm_wordcount | 6604660 | 4066383 | 0.5708 | same |
| core_locals | 4900777 | 3113068 | 0.5889 | same |
| core_qstr | 61539 | 37388 | 0.5632 | same |
| core_str | 5944651 | 4619140 | 0.7203 | same |
| core_yield_from | 3210984 | 3114483 | 0.8992 | same |
| misc_aes | 1370947 | 1168765 | 0.7903 | same |
| misc_mandel | 4948750 | 4081921 | 0.7646 | same |
| misc_pystone | 2946340 | 2101642 | 0.6613 | same |
| misc_raytrace | 5666797 | 4015826 | 0.6569 | same |

`clock_bench.py --before build/sta/base-soc/Vtb_mpy_soc --after
build/mpy_soc/obj/Vtb_mpy_soc --before-ns 10.332 --after-ns 9.578` exits 0
(same images, same output on both executables): every workload has fewer
cycles; pystone 2905788 -> 2070059, the arithmetic loops -0.2 to -0.4 %.

The one change that adds cycles is 19 (one cycle per bigint `//`);
`bm_pidigits` is still 1383634 -> 1342992.

Groups of the final `mpy_soc` report slower than in the baseline by more
than 0.1 ns (every group of both reports compared, `build/sta_trace.py`
with all groups printed). The highest of them is 9.185 ns:

- new groups: `$auto$proc_rom.cc:154:do_switch$1` 9.185 (the register the
  tool puts in front of the `iop_of` table of change 17), a tool-named
  group 9.008 (`wb_v`, packed in change 20; the baseline's `wb_v[0..4]`
  were 9.889 .. 9.286), `lkA` 6.950 (the probe's registers of change 8),
  `qa_pend` 6.558, and the memo and burst registers below that.
- grew: `hm_start` 4.884 -> 7.722; `rf_resume` 6.361 -> 7.443; `rf_pend_v`
  6.480 -> 7.321; `aalu_ret` 5.630 -> 7.305; `dq_bytes`, `d_op` 7.045 ->
  7.266; `aux` 6.949 -> 7.174; `scr_gt` 6.986 -> 7.157; `scr_i` 6.860 ->
  7.035; `md`, `mt`, `ha_mdarg` 6.241 -> 7.021; `at_q` 6.207 -> 7.010;
  `tr_v` 6.318 -> 6.949; `tb_nz`, `tb_n`, `tb_from` 6.397 -> 6.904; `xc`
  6.455 -> 6.887; `inj` 5.904 -> 6.887; `cv_i` 5.909 -> 6.874; `lk_set`
  6.189 -> 6.844; `sw_k` 6.074 -> 6.822; `fflags` 6.156 -> 6.771;
  `rf_pend` 6.358 -> 6.732; `rx_from` 6.145 -> 6.731; `tb_src` 6.203 ->
  6.711; `lk_mode` 6.074 -> 6.711; `b0` 6.078 -> 6.678; `ovr` 5.892 ->
  6.656; `lk_hasav` 6.051 -> 6.633; `scr_ret` 6.244 -> 6.564; `cv_n`,
  `cv_j`, `cv_fidx`, `cv_bm`, `cv_base` 6.190 -> 6.470; `s0`, `s1` 6.073
  -> 6.354; `cv_wide` 6.054 -> 6.320; `ke_a`, `ke_b` 6.024 -> 6.262; `qid`
  5.976 -> 6.149; `lc_dirty` 5.876 -> 6.140; `bl_k` 5.761 -> 5.971;
  `lk_ro` 5.696 -> 5.956; `u_alu.op` 3.580 -> 3.689; `hm_done` 3.214 ->
  3.374 (all `u_core`).

## Paths left, and why

Top of `build/sta/b5-soc/sta.txt`:

| ns | group | start | why it stays |
|---|---|---|---|
| 9.578 | `bulk_engine.engine.req_o` | `c_pend` | `c_pend` -> core address mux -> the accelerator scoreboard's range compares (`chk_busy`) -> `ca_busy` -> core request -> `mpy_mem` `lost` -> accelerator grant -> engine next state. A cut registers the scoreboard test, which is a cycle on every core memory access, or reorders the grant on an invariant that has no proof. |
| 9.423, 9.389 | `copy_engine.fc`, `rpend` | `c_pend` | the same path into the copy engine |
| 9.532 | `u_core.x0` | `ha_mdarg` | `S_SRD_T1` address expression into an add; 0.17 ns above the wall |
| 9.473 | `u_fpu.u_div.s1_exp_a_r` | `state_r` | FP divide stage 1, untouched; 0.11 ns above the wall |
| 9.445 | `u_core.st` | `sp` | ring read of the top of stack into the `S_EXEC` case; was 10.332 |
| 9.390, 9.376 | `cv_fun_g`, `c_addr` | `rf`, `xsp` | start with `has_link`, a ring read through `rf_base` (2.56 ns) |
| 9.366 | `u_hmod.*`, three `modulo.*` | `d3_r` | the sequential modulo at `BPC=4`: two radix-4 steps of a 35-bit subtract and select in a clock. `BPC=2` halves the path and doubles the steps of every `%` the memos do not catch. |

The worst path is 0.21 ns above that 9.366 ns wall. It and seven more
groups sit above the wall, so cutting all eight is worth 2.2 % of the
period, and the first one costs a cycle per core memory access. Below the wall the list is dense
(`addr_o` 9.329, `short_engine.st` 9.246, `pc` 9.207, `s1_shift_r` 9.203).
Cycle changes 22 and 23 each bought more than that (4.8 % and 2.9 %).

Cycle sinks measured in the profile of change 22's simulator and not
taken: one stream of key and value loads over several probe slots with a
count of answers to drop (about 3 % by the profile's `S_LK_PB` share and
1.5 to 3.6 probes per lookup; it changes the core's ack bookkeeping); the
allocator's wait (about 18 cycles per allocation: scan, claim, zero
stores); the call frame fill and spill (`S_FL_H` 3.5 %, `S_SP_H` 3.2 %).

## Checks on the final tree

All on commit 6a3a056 (the tree of change 25).

| check | command | result |
|---|---|---|
| SoC STA | `python3 upycore/tools/sta/run.py mpy_soc --lib "$SKY130_LIB" --no-fsm` | worst 9.578 ns, baseline 10.332 |
| core STA | same, `mpy_core` | worst 9.532 ns, baseline 10.314 |
| unit benches | `make test-unit` | 37 of 37 passed |
| 16 kernels | `shortlist_bench.py` N=100 M=100 and `perf_inventory.py --bigint --only bm_pidigits --points 100x100`, on `build/mpy_soc/obj/Vtb_mpy_soc` | every `RESULT` the baseline's; table above |
| 16 kernels, `+define+MPY_CHECK` build | same, on `build/sims/b5-chk` | every `RESULT` the baseline's, no assertion |
| matched images | `clock_bench.py --before ... --after ... --before-ns 10.332 --after-ns 9.578` | exit 0 |
| hardware suite, mpy-cross | `make test-hw` | **548 of 549 passed; `irq/pin_irq` fails** |
| hardware suite, uPy2 | `python3 upycore/tools/hw_tests.py --compiler mpyc` | 548 of 549, the same failure. Every uPy2 image was byte-identical to mpy-cross's, so the tool reused the first pass's runs and simulated nothing again. |
| clock-ratio sweep | `hw_tests.py --area irq` / `io` / `console` with `--sim-arg +IO_CLK_NS=10` and `+IO_CLK_NS=6.667` | all pass (8, 11 and 9 tests at each), `pin_irq` included |

### `irq/pin_irq` fails at the default clock ratio

The last line of the golden is `coalesced 1`; the device prints
`coalesced 2`. The program toggles a looped-back pad four times in one
line and expects one call of the soft handler for the four edges. The
rule the I/O core documents is that edges which arrive before the
handler runs give one call. Whether all four arrive before the hart
runs the handler is a race between the hart and the I/O core's firmware
loop, and the golden holds only on one side of it:

| simulator | `+IO_CLK_NS` at which `pin_irq` passes | fails |
|---|---|---|
| baseline (`build/sta/base-soc/Vtb_mpy_soc`) | 6.667, 10, 20 (default), 22 | 25, 30, 40 |
| change 22 (`build/sims/b1`) | 20 | |
| changes 23 and 24 (`build/sims/b2`, `b3`) | | 20 |
| change 25, this tree (`build/sims/b5`) | 6.667, 10, 12, 14, 16, 18 | 20 (default), 22, 25, 30, 40 |

So the baseline RTL prints `coalesced 2` as well once the I/O clock is a
quarter slower, and this tree prints `coalesced 1` at both ratios of the
documented sweep. The hart now runs this code in fewer cycles (change 23
is the one that crosses the default ratio), so its handler runs before
the fourth edge has been counted. The other lines of the golden, and the
other seven `irq` tests, pass at every ratio tried.

The golden and the program are unchanged: the round's rules do not allow
editing a test to make it pass. The test is wrong in that its last line
depends on the clock ratio, and it is left failing for the owner to
decide. A copy of the program kept under `build/` that holds events off
across the four toggles (`machine.disable_irq()`, the toggles,
`time.sleep_ms(1)`, `machine.enable_irq()`) prints `coalesced 1` on this
tree at `+IO_CLK_NS=6.667`, 20 and 40, so the coalescing itself works
and that form of the test does not depend on the ratio.
Without changes 23 to 25 the suite's default-ratio run passes and the
kernel geomean is 0.8181 cycles, 0.7584 cycles x period.
