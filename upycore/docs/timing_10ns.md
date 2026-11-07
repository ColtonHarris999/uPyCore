# RTL changes toward a 10 ns post-route clock

The design closed at 18 ns after place and route. This round restructures
the paths that set that number, aiming at 10 ns post-route, and measures
what each change costs in cycles. **No timing exception, constraint or
clock setting was changed.** Post-route closure still has to be shown by
the team's Genus/Innovus flow; the numbers below are a pre-placement
estimate (method and limits below).

## Result

| | Baseline (`6c2a0ae`) | Now | Change |
| --- | ---: | ---: | ---: |
| `mpy_core` worst reg-to-reg path (estimate) | 12.84 ns | 7.40 ns | −42.4 % |
| `mpy_soc` worst reg-to-reg path (estimate) | ≥ 12.84 ns | 7.41 ns | ≤ −42.3 % |
| Scaled to the 18 ns post-route baseline | 18.0 ns | ≈ 10.4 ns | |
| Execution time at that period (all workloads) | 1.00 | 0.578 – 0.595 | 1.68 – 1.73× faster |

The SoC figure comes from an analysis copy with a 16-row SRAM model and a
16 KiB collector pool (so the flat netlist fits); all other logic is the
committed RTL. Its first measurement, with the core changes in, was
8.49 ns, set by `mpy_mem`'s split arithmetic and then the shared hash.

The estimate scales the measured 18 ns post-route period by the ratio of
the estimated worst paths; it assumes routing adds the same fraction to
the new worst path as to the old one.

## Method

No Genus or Innovus was available, so every change was measured with an
open flow that models what Genus does, and compared against the same flow
on the baseline:

1. slang (YoWASP Yosys 0.70) reads the RTL exactly as `mpy_synth.py` does.
2. `synth -flatten -noabc`, then ABC `strash; map -D 1000` onto
   `sky130_fd_sc_hd` (tt_025C_1v80 liberty from OpenROAD-flow-scripts).
   Yosys's own ABC pass is skipped: its area script turns every prefix
   adder back into a ripple chain (a 64-bit add measured 9.9 ns that way
   and 2.2 ns with the delay script), which made the old "ABC levels"
   numbers misleading for adder-heavy paths.
3. OpenROAD `repair_design -pre_placement` buffers and sizes high-fanout
   nets (the core has nets with fanout above 1000).
4. OpenSTA reports every register endpoint; `depth_report.py`-style
   grouping names them by RTL register.

The flow has no wires and uses the typical corner. The ss_100C_1v60
corner the team signs off at is about 2.95× slower per cell (median over
39 cells of the sky130 timing tables), and Genus maps better than ABC, so
absolute numbers are not comparable to Genus reports; ratios between the
baseline and a change are what the decisions were based on.

## What changed (all on `benchmark`)

| Commit | Path | Change | Cycle cost |
| --- | --- | --- | --- |
| `4f492bb` | fetch window → decoder → `jt` / `pc` (12–11.6 ns) | S_FETCH registers the aligned 8-byte window; S_DEC decodes from flops; `jt` is formed in S_EXEC from registered `pc`, `arg`, `extv` | a truncated instruction retries one S_FETCH later (pystone +0.06 %) |
| `4f492bb` | `lc_v` → `bov` (12.8 ns) | the override-dict probe flop is matched on the registered store address when the store completes | 0 |
| `4f492bb` | line-cache LRU pick → store address (12.3 ns) | `lc_pick_r` holds the victim, recomputed every cycle; three-level tournament instead of a seven-step scan; simulation checks both | 0 |
| `54c96c6` | FP add round/pack → FPU result select (9.1 ns) | result register | +1 cycle per float add |
| `54c96c6` | float `//` floor | `fd_floor_r`, one extra cycle only on the sign-fix path | rare |
| `e9b2d04` | integer divider clz → shifts (8.7 ns) | alignment gets its own cycle | +1 cycle per int `//`, `%` |
| `aef1953`, `2b0d4c6` | FP mul / div round/pack → FPU result select (8–8.9 ns) | result registers | +1 cycle per float mul, div |
| `2b0d4c6` | `pack_round`'s denormalize shift in series with the rounding add | split into `upycore_f64_denorm` + `upycore_f64_round_pack` (SAT-proven equal); a subnormal result takes one extra cycle | binary64 subnormal results only |
| `3ecb7a0` | ring spill decision (8.3 ns) | S_RF_SPILL sizes the chunk, S_RF_SPILL2 checks and commits | +1 cycle per spill |
| `d2fdae4` | `has_link` (ring read) at the head of `stk_depth` / `stk_hit` chains | per-slot link test, late select of linked / unlinked results | 0 |
| `d2fdae4` | FP mul accept: clz → exponent sum | exponent summed in C1 from registered parts | 0 |
| `9135c00` | call / generator-resume frame bound (two 32-bit adds + compare) | narrow fields summed first, one 32-bit add | 0 |
| `8c0eecf` | `mpy_mem` split arithmetic ahead of block arbitration and grants (8.4–8.5 ns) | `image_words` / `data_words` registered; block from the offset bits | 0 |
| `7e79d72`, `4879bc2` | memory read data → `hash_float` → shared hash result (7.7–7.9 ns) | complex parts registered, then the float hash in two steps (SAT-proven split) | +4 cycles per complex-number hash |

Estimated core worst path after each step: 12.84 → 9.44 → 8.74 → 7.87 →
7.67 → 7.40 ns.

### After merging the short-list engine (`main`, PR 57)

Same flow, on the merged RTL, with both SRAM shapes (mpy_mem's banks and
the GC table) as macro stand-ins whose pins are flops:

| | Before merge | Merged |
| --- | ---: | ---: |
| `mpy_core` worst path | 7.40 ns | 7.51 ns (`sp` → `m_addr`) |
| `mpy_soc` worst path | 7.41 ns | 7.48 ns (copy engine `rpend`) |
| Scaled to the 18 ns post-route baseline | ≈ 10.4 ns | ≈ 10.5 ns |

The short-list states add about 30 memory-access sources to the core's
address select, which moves `sp` → `m_addr` from 7.30 to 7.51 ns. The first
merged SoC run showed 8.41 ns from the boot loader's size arithmetic
through `mpy_gc`'s pool clamp into its table walk; `mpy_gc` now registers
the clamp (fixed from reset release), and its worst path in the SoC is
5.4 ns. The GC table SRAM costs at most +0.33 % cycles on the merged
firmware (`bulk_extended_keys`); every other workload is within +0.06 %.

## Cycle cost

Same images on the baseline and the new simulator (`upycore/tools/clock_bench.py`):

| Workload | Change |
| --- | ---: |
| `misc_aes` | +0.011 % |
| `bm_fannkuch` | +0.031 % |
| `pystone` | +0.062 % |
| integer add / mul / pow loops | 0.00 % |
| float add / mul, mixed add (one op per iteration) | +1.4 – 1.5 % |
| `int_true_div` | +1.0 % |
| project programs (`upycore/programs/bench`) | ≤ +0.03 %, except `intmath` +1.1 % and `float` +3.1 % |

At an unchanged clock the worst case is 3 % slower; at the estimated
period (18 → ≈10.4 ns) every workload runs ≈1.68–1.73× faster in time.

## Verification

- Hardware suite: 490 of 491 pass; the failure, `calls/star_wide_oom`,
  fails the same way on the starting commit (it came in with later
  `benchmark` work, not with this change).
- Unit benches pass, plus the new `tb_upycore_fp_subnormal` (12 000 checks,
  2 551 subnormal results against IEEE double arithmetic). `mpy_boot`
  times out on the starting commit too.
- Simulation assertions on every use of `lc_pick_r` and on the tournament
  against the original scan, every cycle, across the suite.
- SAT proof that the split `pack_round` equals the original for all 71
  input bits.

## Open items for the backend run

- Rerun Genus/Innovus at 10 ns with the existing constraints and floorplan;
  regenerate `converted/*.v` and `RTL_STAMP` first.
- `mpy_gc`'s allocation table was 30 640 × 2 bits of flops (≈61 k flops),
  sized for an image of size 0. It is now sized for the largest heap a
  real image leaves (`GC_TABLE_BYTES`, 19 200 blocks; see
  `mpy_memory_map.md`) and held in a `fakeram_d600_w64` macro. In the
  estimate flow, `mpy_gc` went from 5.83 mm² (39.6 k flops) to 0.107 mm²
  (2.0 k flops, macro excluded), worst path 4.9 → 4.6 ns; workloads cost
  at most +0.33 % cycles (`bulk_extended_keys`), most ≤ +0.05 %. Add the
  macro to `make sram` and the floorplan.
- What is left is a plateau at 7.1–7.4 ns (estimate) in three places: the
  core's state-machine outputs (`m_addr`, `m_be`, `wret`, `st`, `rstk`)
  after the per-state arithmetic; the copy engine's response to a grant
  (`rpend`, `rn`, `ra`); and the SRAM enables, both behind the
  accelerator scoreboard check (the core's address against every queued
  copy range) and `mpy_mem`'s block arbitration. Going further means a
  registered scoreboard check or splitting the address/next-state logic,
  which costs a cycle on memory accesses; at ≈4 % of period that did not
  pay for itself here.
