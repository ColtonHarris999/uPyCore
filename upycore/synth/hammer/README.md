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
| `cfg/constraints.tcl` | rewritten: `create_clock` on `clk_i` at `--period` ns, I/O delays of `--io-frac` x period (class default 0.5), sky130 driving cell and load, false path from the async reset `rst_n_i`. The example's file is kept as `constraints.tcl.orig` |
| `cfg/*src.yml` | `synthesis.inputs.input_files` set to the generated file, in the example's path style |
| `cfg/*tb.yml` | testbench and trace lists emptied (synthesis only) |

The script prints a WARNING if the example didn't have a file or key it
expected. Compare `constraints.tcl` with `constraints.tcl.orig` once: if
the class writes a line differently (for instance the driving cell), use
the class's form.

## Where the numbers are

After `make syn`, in `build/syn-rundir/`:

- `reports/final_area.rpt`: area by hierarchy (the per-unit breakdown)
- `reports/final_gates.rpt`: area by cell type (count the flip-flops here)
- `reports/final_time_ss_100C_1v60.setup_view.rpt`: setup timing and slack
- `genus.log`: warnings (latches, undriven nets, removed flops)
- `<top>.mapped.v`: the gate netlist

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
    --clock clk --reset rst_n --also-clock clk_always_on --period 25
```

`--config default` is exactly the benchmarked configuration. `bench-isa`
also turns off what the benchmark binaries never execute (Zbc, Zbkx,
Zilsd, Zclsd, Xh3bextm, debug, triggers, PMP, U-mode), which is the fairer
area comparison. Report which one you used. `clk_always_on` is a second
clock input (the testbench ties it to `clk`); `--also-clock` gives it a
clock at the same period so its flops are timed.

## What to synthesize

- `mpy_core`: the processor, with the ALU, FPU and decoder inside it. This
  is the main number.
- `mpy_alu`: a sub-block of the core. Use it first to shake out problems.
- `mpy_gc`: its allocation table (about 28k bits) would become flip-flops.
  Leave it out, or later map the table to a `bsg_fakeram` macro (Module 2).
- Not `mpy_container`: no other module instantiates it.
- Not `mpy_mem` or `mpy_soc`: 768 KiB of memory arrays.

## If the tool rejects the SystemVerilog

The generated file elaborates cleanly in slang. If Genus rejects a
construct, send the `genus.log` error; it can be fixed in the RTL or
worked around by converting the file with sv2v.
