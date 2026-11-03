# Place-and-route timing plan (draft 1)

Goal: make the uPyCore core (`mpy_core`) close timing after place and route
in the EE 477 flow (Innovus, sky130_fd_sc_hd, setup corner ss_100C_1v60)
**without changing what the design does**. Every change here is a
restructuring of logic that produces the same value in every register and
on every output port on every clock cycle as the code it replaces.

## Hard rules for whoever implements this

1. **Cycle-exact.** No change may alter any output port or any
   architecturally visible register on any cycle. In particular: no new
   pipeline stages, no change to a unit's latency, no parameter change that
   changes cycle counts (for example `upycore_umod_seq` `BPC`), no change to
   handshakes. A change that would need extra cycles is out of scope; list it
   under "Ideas that change timing behavior" at the end instead.
2. **Tests stay green and untouched.** Do not edit, skip, or regenerate any
   test, golden, or testbench. `make test` must pass with the same results as
   the baseline (record the baseline first, see Step 0).
3. **Cycle counts identical.** `python3 upycore/tools/bench.py` must print
   the same cycle count for every benchmark and configuration before and
   after. This is the strongest end-to-end check that behavior is unchanged.
4. **Commit often.** One commit per sub-step below, each one passing the
   checks for that step, pushed right after it is made. Never batch several
   steps into one commit. Commit messages say what changed and which check
   proved it equivalent.
5. **Prove local equivalence where possible.** For each rewritten module,
   keep the original as a reference copy outside `upycore/rtl/` (e.g.
   `build/equiv/<module>_ref.sv`, not committed) and run a Yosys
   equivalence check of old vs new (recipe in "Checks"). Report the result in
   the commit message.
6. RTL lives on `main`. Work on a branch off `origin/main` and open a PR into
   `main`. Do not touch `upycore/synth/hammer/` except as described in Step 4.

## Evidence (post-route, two runs, design from `synth` at cd89ae0)

| Run | Clock | Worst slack | Worst path | Data path |
|---|---|---|---|---|
| upycore_par_p20 | 20 ns | −4.175 ns | `u_hmod/d_r_reg[12]` → `u_hmod/rem_o_reg[31]` | 23.8 ns |
| upycore_par_p15 | 15 ns | −3.920 ns | `u_hmod/r_r_reg[24]` → `u_hmod/r_r_reg[30]` | 18.4 ns |

- All of the 50 worst paths reported in each run start and end inside
  `u_hmod` (`upycore_umod_seq`, instantiated at `mpy_core.sv:1161` with
  `BPC(4)`), except one at −3.265 ns in the 20 ns run:
  `lc_v_reg[0]` → the enable of a Genus-inserted clock gate
  (`CLKGATE_RC_CG_HIER_INST27`).
- The worst path walks through the four unrolled restoring steps of
  `upycore_umod_seq.sv` lines 63–72. In the netlist each step is a
  comparator (`gte_4567_16_I1..I4`) **followed by** a subtractor
  (`SUB_UNS_OP..OP6`) and a select, so the path holds about eight 33-bit
  carry chains in series, plus high-fanout select nets (fanout 16–26).
- Post-route area 1.33 mm² (20 ns). Routing added about 10% over
  synthesis.
- Earlier synthesis-only runs at 15 ns had the worst path in `u_alu` →
  `res_o_reg[63]`. Once `u_hmod` is fixed, that is the likely next path.
- Local logic-depth ranking (`depth_report.py` on the flat Yosys netlist of
  `converted/mpy_core.v`) is running and will be appended here as the
  ranked list of the next targets.

## Step 0: baseline (no RTL change)

- `make test` and save the summary (pass/fail counts) to
  `build/timing_baseline/test.txt`.
- `python3 upycore/tools/bench.py > build/timing_baseline/bench.txt`.
- `python3 upycore/tools/mpy_synth.py --depth 0 mpy_core` (or the
  `read_verilog` fallback in "Checks" if the slang plugin is missing) and
  save the top 60 endpoints to `build/timing_baseline/depth.txt`.
- Nothing to commit unless a helper script is added.

## Step 1: `upycore_umod_seq`, one carry chain per restoring step

Today each step computes `t >= {1'b0, d_r}` and then `t - {1'b0, d_r}` as
two separate operators, and synthesis chains them. Compute the difference
once, 34 bits wide, and take the select from its borrow bit:

```systemverilog
logic [33:0] diff;
diff = {1'b0, t} - {2'b0, d_r};
r_nx = diff[33] ? t[31:0] : diff[31:0];
```

Same values as before: `t >= d` exactly when the subtraction does not
borrow, and when it does not borrow `diff[31:0] == 32'(t - d)`. The
invariant `r < d` keeps `t < 2d`, so the result still fits in 32 bits.

Checks: equivalence vs the original module (all three `BPC` values),
`make test`, bench cycle counts, depth report for `u_hmod` endpoints.
Commit.

## Step 2: `upycore_umod_seq`, radix 4 within the same cycle

With `BPC = 4` a cycle still does four dependent subtractions. Replace the
four radix-2 steps with two radix-4 steps that produce exactly the same
`r_nx` and `q_nx`:

- Each radix-4 step brings down two bits: `t4 = {r, q[31:30]}` (34 bits).
- Compare `t4` against `d`, `2d` and `3d` **in parallel** (three
  subtractors, each with a borrow bit as in Step 1) and pick the largest
  multiple that does not borrow. The new remainder is the matching
  difference, or `t4` if all three borrow.
- `3d` needs an adder. Hold it in a new register `d3_r` loaded at
  `start_i` with `d_i + (d_i << 1)` (35 bits). This adds one register and
  an adder on the start path, but no cycle.
- `BPC = 2` uses one radix-4 step and `BPC = 1` keeps the radix-2 step.

This cuts the serial chain per cycle from four subtractions to two. The
register values each cycle are the same as before because a radix-4
restoring step is two radix-2 restoring steps by definition.

Checks: as Step 1. The equivalence check has to cope with the extra
register `d3_r` (see "Checks": use the miter with bounded proof plus
induction). Commit.

If the depth report shows the start-cycle logic (`clz32` on `a_i` and
`d_i`, the `a_i < d_i` compare, and the 64-bit shifts by `kr`) is now
deeper than the step logic, add **Step 2b**. Restructure that path the
same way, using a borrow-based compare and a mux tree shift with no
change to values. Commit separately.

## Step 3: next targets from the depth report

Take the deepest endpoint groups outside `u_hmod` from the depth report
(appended here before implementation starts), in order. Expected
candidates are the `u_alu` result path (`res_o_reg[63]`) and the
`lc_v_reg` enable logic. For each group, one commit, using only
cycle-exact techniques:

- Merge compare and subtract (as Step 1). Compute several candidates in
  parallel and select late, instead of computing in series.
- Move a slow select off the critical input. For example, precompute
  both outcomes and mux by the late signal.
- Replace priority chains (`if / else if` ladders, `casez` on wide keys)
  with parallel one-hot selects where the conditions are mutually
  exclusive. Prove the exclusivity with an assertion or a short argument
  in the commit message.
- Duplicate a register that has very high fanout. The copies must load
  the same value under the same enable, so behavior stays identical.
  Mark it with a comment so synthesis keeps it.
- Precompute a value one cycle early into a new register **only** when
  its inputs are already registered and stable that earlier cycle in
  every case. The new register must not change any existing register's
  value or timing. Prove this with the equivalence check.

Stop when the depth report's deepest group outside `u_hmod` is no deeper
than the deepest path in `u_hmod` after Step 2. Also stop after five
groups, whichever comes first. Then hand off for a real P&R run.

## Step 4: hand-off for place and route

- After the PR is reviewed, `converted/*.v` on the `synth` branch must be
  regenerated with `upycore/synth/hammer/convert_rtl.sh`. It needs sv2v
  (release binary from github.com/zachjs/sv2v; it does not run on the lab
  machines). That also rewrites `converted/RTL_STAMP`, without which
  `sweep.sh` refuses to run. Commit and push to `synth`.
- justin reruns `~/upycore/upycore/synth/hammer/sweep.sh par 20 15` on the
  lab machine and pastes `sweep.sh par-status` plus the new worst path.
  That decides whether a second round of Step 3 is needed.

## Checks (recipes)

Equivalence, same registers (Step 1, and most of Step 3):

```
yosys -p "read_verilog -sv build/equiv/upycore_umod_seq_ref.sv; rename upycore_umod_seq gold;
          read_verilog -sv upycore/rtl/upycore_umod_seq.sv; rename upycore_umod_seq gate;
          proc; opt_clean; async2sync;
          equiv_make gold gate equiv; hierarchy -top equiv;
          equiv_simple -seq 5; equiv_induct -seq 5; equiv_status -assert"
```

Equivalence, added registers (Step 2): build a miter and prove the outputs
equal from reset. `miter -equiv -flatten -make_assert gold gate miter`,
then `sat -verify -prove-asserts -set-init-zero -seq 40 -show-ports miter`
(40 cycles covers a full operation, at most 9 cycles). Then also run
`sat -tempinduct -prove-asserts -set-init-zero miter`. If the induction
fails only because of unreachable states (for example `d3_r != 3 * d_r`),
say so and rely on the bounded proof plus the full test suite.

For a module that includes `.svh` headers, run `upycore/tools/mpy_dc_unit.py`
first to get a single self-contained `.sv` for both versions.

Depth without the slang plugin: `yowasp-yosys` (pip) with
`read_verilog -sv <single-unit .sv>; synth -flatten -noshare -top <top>;
write_json x.json`, then `python3 upycore/tools/depth_report.py x.json
--top-module <top>`. For `mpy_core` this is slow (tens of minutes), so
use it for a single module (`upycore_umod_seq`, `mpy_alu`) when possible.

## Checker's list (for the review after implementation)

- Every commit is one step, passes its checks, and states the equivalence
  result.
- `git diff origin/main -- upycore/tests upycore/tb upycore/programs` is
  empty. Goldens are unchanged.
- `make test` matches the baseline. `bench.py` cycle counts are identical
  for every benchmark and configuration.
- Rerun the equivalence checks independently from the commit messages.
- Read each rewrite for hidden behavior changes: widths, signedness,
  reset values, X handling, and `BPC = 1` and `2`, which the core does not
  instantiate but which must still be correct.
- The depth report improved for the targeted endpoints, and nothing else
  got deeper by more than a few levels.

## Ideas that change timing behavior (not in this plan; need approval)

- `upycore_umod_seq` `BPC(2)` at `mpy_core.sv:1161`: a single-line change,
  but a dict/set probe start takes up to 16 cycles instead of 8 and
  pystone's cycle count goes up.
- An extra pipeline register in `u_alu` before `res_o`.
