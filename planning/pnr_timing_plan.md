# Place-and-route timing plan (draft 2)

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

## Step 0: tools and baseline (no RTL change)

Tools, if the machine lacks them: `pip install yowasp-yosys` gives
`yowasp-yosys` (use it wherever this plan says `yosys`). Verilator 5 is
needed for `make test`; in the cloud container it is `verilator-cli`, so run
`make test VERILATOR=verilator-cli` (or export `VERILATOR`). If neither is
present, build Verilator from source or use `make docker-test`.

- `make test` and save the summary (pass/fail counts) to
  `build/timing_baseline/test.txt`.
- `python3 upycore/tools/bench.py > build/timing_baseline/bench.txt`.
- Opcode traces: for each program in `upycore/programs/bench`, run the SoC
  simulator with `+TRACE=1` (`tb_mpy_soc.sv:10`) in the same way `bench.py`
  runs it, and save each trace to `build/timing_baseline/trace_<prog>.txt`.
  After every RTL step these must be byte-identical.
- The umod testbench at the widths `make test` skips (it only runs BPC 4,
  `unit_tests.py:82`): build `upycore/tb/tb_upycore_umod_seq.sv` by hand
  with the same Verilator flags as `unit_tests.py` plus `-GBPC=1`, and again
  with `-GBPC=2`, and run each with `+SEED=1`, `+SEED=2`, `+SEED=3`. Do not
  edit the testbench.
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

Same values as before for every input (no invariant needed): `t >= d`
exactly when the 34-bit subtraction does not borrow, and then
`diff[31:0] == 32'(t - d)`. The reviewer proved this with the
same-registers recipe below for BPC 1, 2 and 4 in seconds, and the recipe
catches a planted bug (`diff[32]` for `diff[33]`).

Checks: same-registers equivalence vs the original for BPC 1, 2 and 4;
`make test`; the hand-built umod testbench at BPC 1 and 2; bench cycle
counts and opcode traces identical; depth report for `u_hmod` endpoints.
Commit.

## Step 2: `upycore_umod_seq`, radix 4 within the same cycle

With `BPC = 4` a cycle still does four dependent subtractions. Replace the
four radix-2 steps with two radix-4 steps that produce exactly the same
`r_nx` and `q_nx`:

The step logic, exactly (from the reviewer's prototype, which passes the
checks below):

```systemverilog
logic [33:0] d3_r;   // 3 * d_r, loaded with d_r; reset to 0

// On start_i, next to d_r <= d_i:
//     d3_r <= {2'b0, d_i} + {1'b0, d_i, 1'b0};
// and d3_r <= '0 in the reset branch.

always_comb begin
    logic [32:0] t;
    logic [33:0] t4;
    logic [33:0] dif2;
    logic [34:0] e1, e2, e3;
    r_nx = r_r;
    q_nx = q_r;
    if (BPC == 1) begin
        t = {r_nx, q_nx[31]};
        q_nx = {q_nx[30:0], 1'b0};
        dif2 = {1'b0, t} - {2'b0, d_r};
        r_nx = dif2[33] ? t[31:0] : dif2[31:0];
    end else begin
        for (int j = 0; j < BPC/2; j++) begin
            t4 = {r_nx, q_nx[31:30]};
            q_nx = {q_nx[29:0], 2'b0};
            e1 = {1'b0, t4} - {3'b0, d_r};
            e2 = {1'b0, t4} - {2'b0, d_r, 1'b0};
            e3 = {1'b0, t4} - {1'b0, d3_r};
            if (!e3[34])      r_nx = e3[31:0];
            else if (!e2[34]) r_nx = e2[31:0];
            else if (!e1[34]) r_nx = e1[31:0];
            else              r_nx = t4[31:0];
        end
    end
end
```

The priority 3d, then 2d, then d, then none is required, not a style
choice. With `d_r == 0` (which can reach the ports even though the core
never starts a probe with alloc 0) every subtraction succeeds and only
this order matches the original, which then just shifts bits in.

Why the values match: a radix-4 restoring step is two radix-2 restoring
steps. When `r < d`, `t4 = 4r + b < 4d`, so at most one of `3d, 2d, d`
fits as the largest, and the result is the same remainder the two radix-2
steps leave. `r_r < d_r` holds on every reachable state: reset sets both to
0 (the `d == 0` case above), the accept cycle loads `r = a >> kr`, which
has fewer significant bits than `d` (module header comment), and each step
keeps `r < d`.

Checks for this step (the same-registers equivalence fails by design,
because the new step is only equal on reachable states):

1. Step proof under the invariant: the combinational module
   `stepeq.sv` (reviewer's, in `/mnt/project-files/plans/review/`; copy it
   to `build/equiv/`) computes four radix-2 steps and two radix-4 steps
   from free `r, q, d` and asserts they agree whenever `d == 0 || r < d`.
   Prove with `yosys -p "read_verilog -sv stepeq.sv; proc; flatten;
   sat -prove ok 1 -verify stepeq"`. Repeat for one radix-4 step vs two
   radix-2 steps (BPC 2).
2. The invariant argument above, written in the commit message.
3. Smoke check: the bounded miter from reset at depth 40 (recipe in
   "Checks"), BPC 1, 2 and 4. It passes in about 30 s. Do not run
   `sat -tempinduct` here; it does not converge.
4. `make test`, the hand-built umod testbench at BPC 1 and 2, bench cycle
   counts and opcode traces identical.

Commit.

If the depth report shows the start-cycle logic (`clz32` on `a_i` and
`d_i`, the `a_i < d_i` compare, and the 64-bit shifts by `kr`) is now
deeper than the step logic, add **Step 2b**. Restructure that path the
same way, using a borrow-based compare and a mux tree shift with no
change to values. Commit separately.

## Step 3: next targets from the depth report

The ranked targets (file, line, transform, and the module the
equivalence check runs on) are appended below before implementation
starts. Each target is one commit and must name, in the plan and the
commit message, the module the proof runs on. That has to be a small
module (for example `mpy_alu` or a submodule of it, never all of
`mpy_core`, where a proof will not finish).

Allowed transforms, all cycle-exact:

- Merge compare and subtract (as in Step 1). Compute several candidates in
  parallel and select late, instead of computing in series.
- Move a slow select off the critical input. For example, precompute
  both outcomes and mux by the late signal.
- Replace priority chains (`if / else if` ladders, `casez` on wide keys)
  with parallel one-hot selects where the conditions are mutually
  exclusive. Prove exclusivity inside the module's equivalence check.
- Precompute a value one cycle early into a new register, **only** inside
  a module small enough for a Step 2 style step proof under a stated
  invariant. Its inputs must already be registered and stable in that
  earlier cycle in every case.

Not allowed: register duplication for fanout. Genus merges equivalent
flops, and keeping the copies would need a synthesis constraint, which
Rule 6 rules out.

`lc_v_reg[0]` → clock gate enable (−3.265 ns at 20 ns): the endpoint is the
enable of a clock gate that Genus inserted for a register bank's load
enable. Shortening the RTL logic that computes that load enable is in
scope if it is one of the transforms above. Changing clock-gating
settings is a synthesis setting and out of scope.

Stop when the depth report's deepest group outside `u_hmod` is no deeper
than the deepest path in `u_hmod` after Step 2. Also stop after five
targets, whichever comes first. Then hand off for a real P&R run.

### Ranked targets

(Pending: the flat depth ranking of `mpy_core` is still running and will be
appended here, each with file, line, transform and proof module.)

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
          chparam -set BPC 4 gold gate; proc; opt_clean; async2sync;
          equiv_make gold gate equiv; hierarchy -top equiv;
          equiv_simple -seq 5; equiv_induct -seq 5; equiv_status -assert"
```

Run it three times, with `BPC` set to 1, 2 and 4.

Bounded miter from reset (Step 2 smoke check, and any change that adds
registers): `miter -equiv -flatten -make_assert gold gate miter`, then
`sat -verify -prove-asserts -set-init-zero -seq 40 -show-ports miter`.
40 cycles covers a full operation (at most 9 cycles). It is a smoke
check, not a proof; the proof for such a change is a combinational step
proof under a stated invariant, like `stepeq.sv`.

Step proof under an invariant (Step 2): copy
`/mnt/project-files/plans/review/stepeq.sv` to `build/equiv/`, change its
second `always_comb` to match the step logic actually written (it must be
the same code), and run
`yowasp-yosys -p "read_verilog -sv stepeq.sv; proc; flatten; sat -prove ok 1 -verify stepeq"`.
It passes for all `r, q, d` with `d == 0 || r < d` in about 3 minutes, and
it fails on a planted off-by-one in the 3d difference. Make a BPC 2 copy
(two radix-2 steps against one radix-4 step) and prove that too.

Time limit: if an equivalence proof does not finish in 30 minutes, the
change is dropped (reverted), not committed unproven.

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
- `make test` matches the baseline, and so does the hand-built umod
  testbench at BPC 1 and 2. `bench.py` cycle counts and the `+TRACE=1`
  opcode traces are identical for every benchmark.
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
