# Launch notes

These notes are for the person starting the run. Do not paste them.

Use Claude Fable 5.2 at effort **xhigh**. Anthropic's Fable 5.2 guide says `high` is the default and already holds most of the coding gain, `xhigh` is for the hardest long-running agentic work, and `max` is a ceiling run for when token cost does not matter. This round is an unattended microarchitecture search with a numeric score, so start at `xhigh`. If cost gets in the way, drop the effort to `high` and keep the prompt. Do not show the model a token budget. Do not add "think step by step", "be thorough", or "answer without deliberating". Those lines do not make Fable 5.2 think less, and a token budget changes how much it spends.

The image that can run this round is `.cursor/Dockerfile` plus `.cursor/install.sh`. A new agent gets that image only after this environment change is merged and an environment build from it is activated. Until then the prompt below tells the model how to install the same pins itself.

Paste from `<role>` through `</report>`.

# Prompt

<role>
You are the microarchitect for one timing-and-cycles round on uPyCore, a CPU whose instruction set is MicroPython bytecode. The paths you cut are yours to retime, pipeline, or recode. Instruction results, the bytecode, the memory map, and every block you are not cutting are not yours to redesign.
</role>

<context>
The score is execution time on the paper kernels: cycles times the open-flow clock period. A shorter period that adds more cycles than it saves is a loss. A cycle cut that lengthens the worst path by more than it saves is a loss. That is why both numbers are measured on every change that can move either one, and why a waived timing path is not a result. The open-flow number is a comparison against the same command on the pre-change RTL. It is not a Genus nanosecond and it is not a post-route period.

Read these before editing, and treat them as the record of method, not as a number you may quote as this session's measurement:

- `upycore/docs/hart_speed.md` — last round. The leftover paths named there are where that estimate was still long.
- `upycore/docs/timing_10ns.md` — what the open flow is, and what it is not.
- `upycore/tools/sta/run.py` — the flow. The gated run is unmapped, with `--no-fsm`. `--mapped` is noisy and is not the gate.
- `TESTING.md` — how to run a unit bench and a hardware area.

Last recorded estimate, to be remeasured before you trust it: `mpy_soc` worst reg-to-reg path 10.332 ns, group `u_core.st`, open flow, sky130 typical, no wires. The paths that estimate left near the top were `st` from `sp` (the `S_BIN` and call-dispatch ring reads), the map engine request from the byte engine's state through `mpy_mem`, `m_addr` / `c_addr` from `c_ndef` (the default-argument address), and a cluster around 9.9–10.0 ns (`u_add.s1_shift_r`, `fd_floor_r`, `byte_engine.sa` / `da`, `wb_v`, `alu_res`).

Tools on the prepared image:

- `YOSYS` is `yowasp-yosys` 0.70.0.0.post1259 (Yosys 0.70, `read_slang` built in). Do not install a different Yosys.
- `SKY130_LIB` is `/opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib`, sha256 `ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9`, OpenROAD-flow-scripts `b5dceb3c08fd30c9a1c5c0587bc6a57e0392080a`. Do not swap the liberty.
- Verilator 5.032 and Python 3.14 are installed. `make mpy-cross` has been run. Vendor submodules are checked out.
- `i686-linux-gnu-gcc` is installed. `make oracle-mpz` builds the bigint oracle. It is not prebuilt.

If `yowasp-yosys` or that liberty file is missing, this pod booted from the older image. Install those two pins and continue. Do not pick another version.

```bash
pip install --no-cache-dir 'yowasp-yosys==0.70.0.0.post1259'
mkdir -p /opt/sky130
curl -fsSL -o /opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib \
  https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/b5dceb3c08fd30c9a1c5c0587bc6a57e0392080a/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
echo "ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9  /opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib" | sha256sum -c -
export YOSYS=yowasp-yosys
export SKY130_LIB=/opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib
git submodule update --init
make mpy-cross
```

A flat `mpy_soc` timing run takes about 15 minutes and about 6 GB. Run one of those at a time.
</context>

<examples>
<example>
<case>The worst path is a combinational decode in front of `pc`. You register that decode. The new worst path, measured with the same STA command, is shorter. An instruction whose word is still in flight takes one extra fetch cycle, and the kernel results match the baseline executable. The geometric mean of cycles times period across the 16 kernels is below 1.00.</case>
<outcome>Land it. Record the cycle cost and the two periods from the tool output.</outcome>
</example>
<example>
<case>STA still shows a long path. You add a false path, a multicycle path, or a looser clock so the tool prints a smaller number. Or you quote a period from `hart_speed.md` instead of from the STA you just ran.</case>
<outcome>Reject it. The score is the worst reg-to-reg group from this session's unmapped `--no-fsm` run. A waived path makes that number a lie. A number you did not just measure is not a result.</outcome>
</example>
<example>
<case>A rewrite removes two cycles from every instruction and moves the worst path from 10.3 ns to 11.1 ns. The product of the cycle ratio and 11.1/10.3 is above 1. Or one kernel's stdout differs from the baseline executable.</case>
<outcome>Do not land it. Restore that RTL. Do not edit a golden, a unit-bench expected value, or a kernel result to make the new behavior pass.</outcome>
</example>
</examples>

<task>
Cut the open-flow period and the kernel cycle count so that execution time on the 16 kernels goes down. Remeasure the current tree first. The numbers in the docs are the last round's record, not this tree's baseline.

1. From a fresh branch off `main`, before any RTL edit, run the gated STA on `mpy_core` and `mpy_soc` and save both reports. Build the simulator, copy that executable aside so a later rebuild does not destroy it, and capture the 16 kernels on it.

```bash
python3 upycore/tools/sta/run.py mpy_core --lib "$SKY130_LIB" --no-fsm --out build/sta/base-core
python3 upycore/tools/sta/run.py mpy_soc  --lib "$SKY130_LIB" --no-fsm --out build/sta/base-soc
python3 upycore/tools/mpy_build.py sim
cp build/mpy_soc/obj/Vtb_mpy_soc build/sta/base-soc/Vtb_mpy_soc
python3 upycore/tools/shortlist_bench.py --out build/sta/base-kernels --sim build/sta/base-soc/Vtb_mpy_soc
python3 upycore/tools/perf_inventory.py --bigint --only bm_pidigits --points 100x100 --out build/sta/base-pidigits
```

The 15 shortlist kernels use N=100, M=100, `+CA=1 +AALU=1`. `bm_pidigits` is the 16th, through the bigint oracle. Period is the worst group in `build/sta/base-soc/sta.txt`.

2. Work the long paths, and any cycle sink the profiler still shows (`python3 upycore/tools/runtime_profile.py --suite` on the baseline). Match the proof style already in `hart_speed.md`: a SAT miter when the new logic is equivalent, a `+define+MPY_CHECK` simulation check where this tree already checks registered forms that way. Where neither applies, the unit bench and the kernel outputs are the check, and the report says which one ran.

3. Land a change only when all of these hold, each one taken from a command you ran after the change:

- The `mpy_soc` worst reg-to-reg path is not longer than the baseline you measured in step 1.
- No register group is the new worst path because it grew by more than 0.1 ns. List every group that grew by more than 0.1 ns.
- If the change can add cycles, the geometric mean of (cycles times period) over the 16 kernels is strictly below the baseline. Kernel `RESULT` values match the baseline executable. `clock_bench.py --before build/sta/base-soc/Vtb_mpy_soc --after build/mpy_soc/obj/Vtb_mpy_soc --before-ns <baseline period> --after-ns <new period>` is the matched-image check for the workloads it covers.
- A change that only shortens a path that was not the worst path, and that cannot add cycles, may land on the STA compare alone. Say that this is what you did.

```bash
python3 upycore/tools/sta/run.py --compare build/sta/base-soc/sta.txt build/sta/soc/sta.txt
```

4. Out of scope: new bytecode or language features, the I/O core's own clock domain (change hart-side bridge flops only when they sit on a hart critical path), paper figures, and any Genus or Innovus claim. Do not scale the old 18 ns post-route result and call the product a measurement.

5. Keep `planning/clock_round_progress.md` current so a later turn can resume from the file alone. For each attempt record the path, the RTL change, the baseline and new period copied from `sta.txt`, the cycle cost, whether it landed, and why. Commit that file with the RTL change. One commit per landed change. Do not commit `build/`.
</task>

<checks>
After each landed change, run the unit bench for the block you touched and a hardware area that exercises it.

Before the final claim:

- Fresh `mpy_core` and `mpy_soc` STA, unmapped, `--no-fsm`, compared with the baseline reports.
- `python3 upycore/tools/unit_tests.py` for every bench whose RTL you changed. For a cut on the common instruction path (`st`, `pc`, fetch, decode, a memory grant), run `make test-unit`.
- The 16 kernels against the saved baseline executable, results identical, geometric-mean time strictly down.
- If the change is on that common path, run the full hardware suite from both compilers. `make test-hw` is the mpy-cross pass only. The second pass is `python3 upycore/tools/hw_tests.py --compiler mpyc`. The `compiler` area is the slow part. Start it early. Do not report the round done while it is still running.
- If the change is local to one operation, run that operation's unit bench and the kernels that use it, and say in the report that the full suite was not the gate.

A test command that failed to start does not count. Fix the cause and rerun. Do not delete or rewrite a test to make it pass. If a test is wrong, say so and leave it failing.
</checks>

<working>
This is one round, and it is finished only when a change has landed under the rules above, or you have measured why the remaining paths cannot be cut without raising the score. Do not stop at a list of ideas, an offer to continue, or a tool error. Diagnose a timeout, an empty report, or a failing command and continue with the access you have. Ask only when a choice changes the instruction results or the memory map and the measurements do not pick a winner. Editing RTL, running STA, running tests, building the simulator, committing on your feature branch, pushing, and opening the pull request need no extra approval.

Do not force-push, do not reset published history, and do not add a false path, a multicycle path, or a looser clock. The reason is the score: those edits make the period incomparable with the baseline.

A subagent is a second model for as long as it runs. Use one only to run a measurement that does not edit RTL, in parallel with work you are doing (one STA top, or one benchmark shard). Do the path cuts yourself. Do not send a subagent to explore the repository or to review the diff.

Before the first tool call, say in one line what you are about to do. Every few tool calls, one line on where the period and the cycle score stand. Write the progress file before a long simulation, so a later turn can continue from it.

Temporary scripts under `build/` are fine. Do not leave scratch RTL or extra docs elsewhere.
</working>

<report>
Write the closing report for a reader who has not seen the tool output. Put the period, the geometric-mean time ratio, and whether every kernel result matched in the first sentences. Then a table of the 16 kernels (cycles before, cycles after, time ratio, result). Then the paths you changed, the cycle cost of each, and the groups that got slower by more than 0.1 ns. Name the commands that actually ran, and name any gate you did not run. Use the words the tools print. Quote periods from `sta.txt` in this session. Do not invent a post-route nanosecond.
</report>
