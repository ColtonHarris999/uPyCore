# uPyCore in the EE 477 Hammer flow

The class flow (`ee477-hammer-cad`) runs Cadence Genus for synthesis
(`make syn`), Innovus for place and route (`make par`) and VCS for
simulation, on the sky130 `sky130_fd_sc_hd` library. Synthesis timing is
checked at the slow corner, `ss_100C_1v60`.

`make_hammer_design.py` turns a working class design folder into a design
folder for a uPyCore top (or for Hazard3, the baseline). It copies the
example rather than guessing the class's file formats, so the Makefile and
the tool and library setup stay exactly as the class has them.

Nothing here has been run on the lab machines yet. Every step was checked
against a mock of the class layout only.

## Do not commit class files

The class materials are under a course NDA. The design folder this script
creates contains the class Makefile and cfg files, so keep it in your
`ee477-designs-*` checkout, never in this repo.

## Steps (on a lab machine, in bash, not tcsh)

```sh
git clone https://github.com/coltonharris999/upycore.git ~/upycore
cd ~/upycore
git checkout claude/project-thread-sh2efy      # until it is merged

# Start with the ALU: smaller, so tool problems show up fast.
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477-designs-module1/pow2 ~/ee477-designs-module1/upycore_alu \
    --top mpy_alu --period 25

cd ~/ee477-designs-module1/upycore_alu
make syn
```

Use `pow2` (or the GCD you build in Module 1 Task 2) as the example: it is
an ordinary clocked design. `clk_gen_ds` is a ring oscillator whose
constraints don't apply to a processor. Put the new folder next to the
example, because the Makefile includes the shared makefile by a relative
path.

Then the core, the same way, with `--top mpy_core`.

## What the script changes

| File | Change |
|---|---|
| `Makefile`, `cfg/*.yml` names | example name replaced with the new folder name |
| `v/` | replaced by one generated file, `v/<top>.sv` (all modules plus inlined headers, `SYNTHESIS` defined) |
| `cfg/*cfg.yml` | `synthesis.inputs.top_module`; placement path renamed to the new top; `vlsi.inputs.clocks` updated only if the example already sets it |
| `cfg/constraints.tcl` | rewritten: `create_clock` on `clk_i` at `--period` ns, I/O delays of `--io-frac` x period (class default 0.5), false path from the async reset `rst_n_i`. The example's file is kept as `constraints.tcl.orig` |
| `cfg/*src.yml` | `synthesis.inputs.input_files` set to the generated file, in the example's path style |
| `cfg/*tb.yml` | testbench and trace lists emptied (synthesis only) |

The script prints a WARNING if the example didn't have a file or key it
expected. Compare `constraints.tcl` with `constraints.tcl.orig` once: if
the class writes a line differently (for instance the I/O delays), use
the class's form.

## Where the numbers are

After `make syn`, in `build/syn-rundir/`:

- `reports/final_area.rpt`: area by hierarchy (the per-unit breakdown)
- `reports/final_gates.rpt`: area by cell type (count the flip-flops here)
- `reports/final_time_ss_100C_1v60.setup_view.rpt`: setup timing and slack
- `genus.log`: warnings (latches, undriven nets, removed flops)
- `<top>.mapped.v`: the gate netlist

## Checking a run

A run that finishes is not necessarily a good netlist. After every
`make syn`, from the design folder:

```sh
python3 ~/upycore/upycore/synth/hammer/check_syn.py
```

It lists errors (marking the expected ones from Hammer's placeholder
`DEFAULT_CLOCK`), warnings by id with the dangerous kinds marked, latch
cells and black boxes in the netlist, and the flop count against the RTL
(slang counts: `mpy_alu` 5552, `mpy_decode` 461, `mpy_core` 12677). Genus
drops constant and duplicate flops, so 85 to 100% of the RTL count is
normal. It exits 1 if anything needs a look.

## Proving the netlist matches the RTL

Conformal LEC proves the gates compute what the RTL does. The RTL passes
the hardware test suite, so a pass carries that to the netlist:

```sh
python3 ~/upycore/upycore/synth/hammer/lec_dofile.py
lec -xl -nogui -dofile lec/lec.do
```

The golden side is `golden/<top>.sv` (kept by `--sv2v`), so this also
checks the sv2v conversion. If Conformal cannot parse it, `--golden v`
compares against the converted file instead. A pass is 0 non-equivalent
and 0 aborted points in `report verification`. Not yet run: written
without Conformal access, so check `lec/lec.log` if a command is rejected.
If the class flow has its own LEC target, use that.

## Finding Fmax

Re-run the script with a smaller `--period` (pass `--force` to overwrite
the folder, or give it a new name) and `make syn` again. For a run at
period P with worst slack WNS, the achievable period is about P - WNS. The
smallest P with WNS >= 0 is the reported Fmax. Keep the reports of every
run.

## Typical-corner timing and power

`genus_reports.tcl` reads the mapped netlist and reports register-to-register
timing, area and power (Genus default switching activity) at another
corner, typical by default:

```sh
genus -batch -files ~/upycore/upycore/synth/hammer/genus_reports.tcl \
      -execute "set TOP mpy_core; set PERIOD 25"
```

Reports go to `build/extra-reports/tt_025C_1v80/`. It assumes the class
PDK is at `/home/projects/ee477/cad/pdk/sky130A` (Module 0); set `LIB_DIR`
if not.

## Hazard3 baseline

Benchmarks used Hazard3 commit `8af9929`, top `hazard3_cpu_2port`, with the
testbench's `config_default.vh`. Synthesizing `hazard3_cpu_2port` directly
would use `hdl/hazard3_config.vh`, which turns most extensions off, so use
`hazard3_rtl.py` to write a configured single file:

```sh
git clone https://github.com/Wren6991/Hazard3.git ~/Hazard3
cd ~/Hazard3 && git checkout 8af9929 && cd ~/upycore
python3 upycore/synth/hammer/hazard3_rtl.py ~/Hazard3 --config bench-isa \
    -o ~/hazard3_cpu_2port.sv
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477-designs-module1/pow2 ~/ee477-designs-module1/hazard3_ds \
    --rtl ~/hazard3_cpu_2port.sv --top hazard3_cpu_2port \
    --clock clk --reset rst_n --also-clock clk_always_on --period 25 \
    --tie-low 'dbg_*'
```

`--tie-low 'dbg_*'` stops timing the debug system-bus port, which
is unused with debug off: it is muxed straight onto the data bus, so with
I/O delays of half the period each way those input-to-output paths fail
at any clock. The logic is still synthesized; only its timing is ignored.

`--config default` is exactly the benchmarked configuration. `bench-isa`
also turns off what the benchmark binaries never execute (Zbc, Zbkx,
Zilsd, Zclsd, Xh3bextm, debug, triggers, PMP, U-mode), which is the fairer
area comparison. Report which one you used. `clk_always_on` is a second
clock input (the testbench ties it to `clk`); `--also-clock` gives it a
clock at the same period so its flops are timed.

## What to synthesize

- `mpy_core`: the processor, with the ALU, FPU and decoder inside it. This
  is the main number.
- `mpy_alu` and `mpy_decode`: the core's only two submodules. Use them to
  shake out problems and for the per-unit area table. Everything else in
  the core is its interpreter state machine, which does not split further.
- `mpy_gc`: its allocation table (about 28k bits) would become flip-flops.
  Leave it out, or later map the table to a `bsg_fakeram` macro (Module 2).
- Not `mpy_container`: no other module instantiates it.
- Not `mpy_mem` or `mpy_soc`: 768 KiB of memory arrays.

## If the tool rejects the SystemVerilog

Genus reads `mpy_alu` as SystemVerilog, but its parser fails on
`mpy_core` (VLOGPT-203 "Unresolved subprogram reference" inside the
interpreter's state machine). `converted/` holds each top already
converted to Verilog-2005 with [sv2v](https://github.com/zachjs/sv2v)
(the lab machines' glibc is too old for the sv2v release binary). Use it
with `--rtl`; the script then also writes the SystemVerilog to `golden/`
for the equivalence check:

```sh
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477/ee477-designs-module1/pow2 ~/ee477/ee477-designs-module1/upycore_core_p50 \
    --top mpy_core --period 50 --rtl upycore/synth/hammer/converted/mpy_core.v
```

After an RTL change, regenerate the files with `convert_rtl.sh` on a
machine where sv2v runs, and commit them. Where sv2v runs on the lab
machine itself, `--sv2v <binary>` converts while building the folder.
The converted files also read cleanly in Yosys's own Verilog parser.

## Power from simulated activity

Vectorless power (Genus guessing how often each net toggles) does not
compare two different cores fairly. `activity/upycore_pystone.saif.gz` is
the switching activity of `mpy_core` running perf_bench `misc_pystone`
(300 loops, MicroPython startup included: 15,235,606 cycles at the
testbench's 10 ns clock). To regenerate it:

```sh
verilator --trace-saif -DMPY_SAIF ...   # the flags mpy_build.py uses, --Mdir build/mpy_soc_saif/obj
MPY_SIM=build/mpy_soc_saif/obj/Vtb_mpy_soc MPY_SIM_ARGS=+SAIF=pystone.saif \
    python3 upycore/tools/mpy_build.py run -v --max-cycles 4000000000 misc_pystone_timed.py
```

Read it into Genus on the mapped netlist, at the simulated 10 ns period:

```sh
gunzip -k ~/upycore/upycore/synth/hammer/activity/upycore_pystone.saif.gz
printf 'set TOP mpy_core\nset PERIOD 10\nset SAIF %s\nset OUT build/extra-reports/saif_pystone\nsource %s\n' \
    ~/upycore/upycore/synth/hammer/activity/upycore_pystone.saif \
    ~/upycore/upycore/synth/hammer/genus_reports.tcl > ~/pw_saif.tcl
genus -batch -no_gui -files ~/pw_saif.tcl
```

Energy per cycle is total power divided by 100 MHz. Check
`saif_annotation.rpt`: the SAIF comes from RTL simulation, so only nets
whose names survive synthesis (flop outputs, ports) are annotated and
Genus propagates the rest.
