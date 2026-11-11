# uPyCore in the EE 477 Hammer flow

The class flow (`ee477-hammer-cad`) runs Cadence Genus for synthesis
(`make syn`), Innovus for place and route (`make par`) and VCS for
simulation, on the sky130 `sky130_fd_sc_hd` library. Synthesis timing is
checked at the slow corner, `ss_100C_1v60`.

`make_hammer_design.py` turns a working class design folder into a design
folder for a uPyCore top (or for Hazard3, the baseline). It copies the
example rather than guessing the class's file formats, so the Makefile and
the tool and library setup stay exactly as the class has them.

This flow produced the 18 ns post-route result and the Genus reports that
`upycore/docs/timing_100mhz.md` and `timing_10ns.md` start from.

## Before the next run (the 32-macro memory)

- **`converted/`** was regenerated for this RTL (bdb4880; only `mpy_soc.v`
  and `RTL_STAMP` changed, the core's logic is the same).
- **Memory.** Each bank is eight `fakeram_d4096_w36` macros (32 in all);
  see "Why 32 macros and not four" below. `check_syn.py` and
  `sweep.sh status` expect 33 macros.
- **Cycles.** Nothing after boot changes: `misc_pystone_timed.py` is still
  `cycles=6635675`. Boot ends 28,672 cycles earlier (`boot=61370`, was
  90042), because the reset clear writes 4096 rows instead of 32768.
- **Timing.** Synthesis met 10 ns with zero slack on the old memory
  (c895f2d: 9 ns -0.662, 10 ns 0, 11 ns +0.022). The memory request path
  now also decodes three row bits into a macro enable, and the read data
  passes an 8:1 mux; the first 10 ns Genus run shows what that costs.
- **Power.** `activity/upycore_pystone.saif.gz` predates the split: its
  memory instances are `g_blk[0..3]`, now `g_mac[0..31]`. Rerecord it
  before a power run of the whole chip.

## Do not commit class files

The class materials are under a course NDA. The design folder this script
creates contains the class Makefile and cfg files, so keep it in your
`ee477-designs-*` checkout, never in this repo.

## Steps (on a lab machine, in bash, not tcsh)

```sh
git clone https://github.com/coltonharris999/upycore.git ~/upycore
cd ~/upycore

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
(slang counts: `mpy_alu` 6180, `mpy_core` 14751; `mpy_decode` has none). Genus
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
- `mpy_gc`: its allocation table (19,200 blocks, the largest heap a real
  image leaves) is a `fakeram_d600_w64` macro; run `make sram` first.
  Boot selects the active subset after subtracting the image from shared
  SRAM.
- `mpy_soc`: the whole chip, with the four 128 KiB SRAM banks as 32
  `fakeram_d4096_w36` macros (eight per bank), the GC table as a `fakeram_d600_w64` macro,
  the SPI NAND boot loader, and the I/O island
  ([`../../docs/mpy_io_core.md`](../../docs/mpy_io_core.md)) with its
  16 KB code and 7.5 KB data SRAMs as `fakeram_d4096_w32` and
  `fakeram_d1920_w32` macros, and its USB SIE's nine 256 × 16 RAMs
  (endpoint buffers and status) as one-read-one-write `fakeram_d256_w16`
  macros behind BaseJump's `bsg_mem_1r1w_sync_mask_write_bit` (44
  macros in all; check that the class `bsg_fakeram` generator takes the
  `1r1w` family, which the uPyCore macros so far have not needed). The script sets up the
  SRAM macros; run `make sram` before `make syn`, and add the macro
  placements. The island runs on its own clock: `constraints.tcl` gets
  `io_clk` on `io_clk_i` (`--io-period`, default 20 ns), asynchronous to
  `core_clk`, every path between the two bounded by `set_max_delay` to
  the faster period (each ends in a two-flop synchronizer or is a
  dual-clock FIFO's memory behind a gray pointer), the island's pads
  timed against `io_clk`, and the UART RX pin and the console strap,
  which are synchronized first, not timed. The USB SIE adds `usb_clk` on
  `usb_clk_i` (`--usb-period`, 48 MHz), asynchronous: its bridge to
  `io_clk` is bounded like the other crossings, D+ and D- in are not
  timed (sampled through the PHY's flops), their drive is timed against
  `usb_clk`. CVE2's clock gate is the
  `sky130_fd_sc_hd__dlclkp_1` cell in the generated file
  (`iocore/rtl/asic/cve2_clock_gate.sv`), so Genus maps no latch. See
  [`../../docs/mpy_boot.md`](../../docs/mpy_boot.md#ee-477-hammer-flow).
  If Genus rejects the SystemVerilog that `--core-v` writes for the
  rest of the chip, use the whole chip converted instead:
  `--rtl upycore/synth/hammer/converted/mpy_soc.v` (no `--core-v`; it
  leaves out the SRAM stand-in, so BaseJump's file and the macro are used).

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
machine where sv2v runs, and commit them. Update `converted/RTL_STAMP`
to the source RTL commit used for the conversion. The `mpy_soc` view
includes the I/O island. Where sv2v runs on the lab machine itself,
`--sv2v <binary>` converts while building the folder.
The converted files also read cleanly in Yosys's own Verilog parser.

## Power from simulated activity

Vectorless power (Genus guessing how often each net toggles) does not
compare two different cores fairly. `activity/upycore_pystone.saif.gz` is
the switching activity of `mpy_core` running perf_bench `misc_pystone`
(`activity/misc_pystone_timed.py`: 300 loops, MicroPython startup
included: 6,635,675 cycles at the testbench's 10 ns clock; the benchmark
itself is 6,262,469, the run less the 373,206-cycle
`activity/misc_pystone_base.py`). It matches the RTL of the 10 ns round
(`main` c895f2d: registered multiplier operands, pow and boot registers).
`upycore_pystone_c788c64.saif.gz` is the same run on the RTL of the
November benchmark round (c788c64: posted stores and burst loads, the core
request skid, the new natives; the same cycle counts).
`upycore_pystone_f15327a.saif.gz` is
the same run on the RTL from aba9ce0 to f15327a (timing pipelines toward
10 ns, short-list engine, GC table SRAM; 12,769,713 cycles, benchmark
12,172,954).
`upycore_pystone_9a20eb2.saif.gz` is the same run on 9a20eb2's RTL (shared
SRAM, pipelined ALU; 12,769,729 cycles, benchmark 12,174,564), the RTL of
the 2500 x 2500 p20 runs.
`upycore_pystone_oct29rtl.saif.gz` is the same run on the RTL with the
iterative probe modulo (14,174,681 cycles, benchmark 13,513,686), and
`upycore_pystone_oldrtl.saif.gz` the RTL before that (15,235,606 cycles,
benchmark 13,409,731), for
netlists synthesized before that change. To regenerate it:

```sh
verilator --trace-saif -DMPY_SAIF ...   # the flags mpy_build.py uses, --Mdir build/mpy_soc_saif/obj
MPY_SIM=build/mpy_soc_saif/obj/Vtb_mpy_soc MPY_SIM_ARGS=+SAIF=pystone.saif \
    python3 upycore/tools/mpy_build.py run -v --max-cycles 4000000000 \
    upycore/synth/hammer/activity/misc_pystone_timed.py
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

After place and route, read the same file into Innovus on the routed
design (unzip it first; give a full path, since Innovus does not expand `~`):

```tcl
read_activity_file -format SAIF -scope tb_mpy_soc/u_soc/u_core /home/<you>/upycore/upycore/synth/hammer/activity/upycore_pystone.saif
report_power -out_file power_saif.rpt
```

The toggle rates in the file are for the simulated 10 ns clock. For a run
at period T, energy per cycle is dynamic power / 100 MHz + leakage x T, and
power at that clock is that energy / T. Without a readable SAIF,
`report_power` silently falls back to the vectorless guess.

Verilator also writes top-level `$unit` and package scopes into the SAIF;
those were cut from `upycore_pystone.saif.gz` (keep only `tb_mpy_soc`),
since nothing annotated with them in place.

`activity/hazard3_pystone.saif.gz` is the same benchmark on the Hazard3
baseline (same MicroPython script, 21,365,266 cycles in all at 10 ns; the
benchmark's own timer reads 12,840,381 cycles, matching the cycle table).
It came from Hazard3's Verilator testbench (commit 8af9929) with
`hazard3_tb_saif.patch` applied and `config_benchisa.vh` in
`test/sim/tb_common/hdl/`, built with
`make CONFIG=benchisa VERILATOR="verilator --trace-saif --timescale 1ns/1ps"`
and run as `HZ3_SAIF=hazard3_pystone.saif tb-benchisa --bin <image>`. From
the Hazard3 design folder:

```sh
gunzip -k ~/upycore/upycore/synth/hammer/activity/hazard3_pystone.saif.gz
printf 'set TOP hazard3_cpu_2port\nset PERIOD 10\nset CLOCK clk\nset RESET rst_n\nset ALSO_CLOCKS clk_always_on\nset SAIF %s\nset SAIF_INSTANCE TOP/tb/cpu\nset OUT build/extra-reports/saif_pystone\nsource %s\n' \
    ~/upycore/upycore/synth/hammer/activity/hazard3_pystone.saif \
    ~/upycore/upycore/synth/hammer/genus_reports.tcl > ~/pw_saif_hz3.tcl
genus -batch -no_gui -files ~/pw_saif_hz3.tcl
```

Both runs include MicroPython startup, which averages into the power. To
compare, take energy per pystone run as power x benchmark cycles x 10 ns.

## Clock sweep

`sweep.sh start 12 10 8` builds `upycore_v2_p<period>` design folders and
starts `make syn` in each at once, in the background (they keep running
after you log out). `sweep.sh status` lists every folder with its state,
slack, critical-path delay, the shortest period its netlist meets
(period - slack) and the cell area. `DESIGNS`, `PREFIX`, `TOP` and `RTL`
override the defaults (`RTL` is gone: the core comes from
`converted/$TOP.v`).

`sweep.sh par 20 15` does the same but runs `make par` after `make syn`, in
`upycore_par_p<period>` folders (default die 1500 x 1500 um for the core).
`sweep.sh par-status` lists each one's post-route slack, shortest period and
total power, and where its area, power and timing reports are.

`sweep.sh collect` gathers the finished `par` runs into one file,
`~/par_data/par_<prefix>.txt` (set `PAR_DATA` to use another folder): constraints, the flow's timing reports (50 paths
each), area and power by module, the Innovus log's density and clock lines,
and Genus's QoR. For more, first run
`source ~/upycore/upycore/synth/hammer/deep_reports.tcl` in a run's Innovus
console (`make open-chip`). It writes `~/par_data/<folder>/deep/` with 3000 setup and
register-to-register paths, hold, DRC, connectivity and clock-tree reports,
and `collect` then adds those, grouped by register bank. `collect` also
copies each run's reports to `~/par_data/<folder>/flow/`, so they outlive
the run folder. `DESIGN_ARGS`
passes options to `make_hammer_design.py`, for example
`DESIGN_ARGS=--no-feedthrough` so input-to-output paths are not timed.

Before starting runs, `sweep.sh` pulls the branch and compares
`converted/RTL_STAMP` with a hash of `upycore/rtl` and the converter
scripts. If the RTL changed and `converted/*.v` were not regenerated, it
stops instead of building old RTL; `convert_rtl.sh` (where sv2v runs)
rewrites the files and the stamp.

`TOP=mpy_soc sweep.sh start 20 15` does the same for the whole chip:
each `upycore_soc_p<period>` folder (`upycore_socpar_p<period>` with `par`) gets the SRAM macros, and the
background job runs `make sram` and then `make syn`. `DIE="w h"` sets the
die (default 4000 x 3000 um) and `SOC_RTL=converted` takes the chip from
`converted/mpy_soc.v`. `TOP=mpy_soc sweep.sh status` adds the macro count
of each netlist (it must be 44: 32 of main memory, the GC table, the I/O
island's code and data SRAMs and the USB SIE's nine) and the
macro footprints from their LEFs.

`TOP=mpy_soc sweep.sh par 15` places and routes the whole chip. Between
`make sram` and `make syn` it runs `place_macros.py`, which reads the LEFs,
places the 33 memory and GC macros as `hardmacro` constraints and sets the
die (DIE is ignored). It does not place the I/O island's 11 macros yet (the
4096 x 32 code SRAM, the 1920 x 32 data SRAM, the USB SIE's nine 256 x 16):
they came with the I/O core (main) after this floorplan was written, and
the 4096-word code SRAM is probably as long as a main-memory macro, so it may
not fit the logic channel. Check them in `sweep.sh floorplan` before a full
run. A 4096-word macro is 3.95 x 0.16 mm with every signal pin on one
short edge. `python3 place_macros.py <folder> --dry-run` prints
the layout without writing it.

The floorplan is two columns of 16 memory macros with the logic in a
channel between them, on a die of about 9.7 x 3.0 mm:

- The left column is mirrored (`my`), so all 32 pin edges face the
  channel. A bank is one quadrant: bank 0 bottom left, 1 bottom right,
  2 top left, 3 top right.
- The channel is sized for the logic at 45% utilization (`--util`,
  `--logic-area`), about 1.5 x 2.8 mm. The GC table macro sits at its
  bottom centre.
- Two placement blockages (`obstruction` constraints) cover everything
  outside the channel. Without them the placer puts cells in the die margin
  and in the 22 um gaps between stacked macros, millimetres from the logic.
- Two routing blockages on met1 to met3 cover the same area, stopping
  5 um inside the macros' pin edges. Without them the router sent a dozen
  nets, each with both pins at a channel edge about 1 mm apart, on 8 to
  9 mm met1 detours along the gaps between stacked macros and round the
  die margin; those nets alone cost 15 ns in the first 12 ns runs.
- The chip's 231 I/O pins get explicit met2 locations on the top edge,
  across the channel only, with `clk_i` in the middle. The class default
  spreads them along a whole die edge, which here runs over the macros.

`sweep.sh floorplan 15` stops Innovus after the floorplan
(`make par-to-floorplan`), so the macros, blockages and pins can be checked
before a full run; `make par-from-floorplan` in the folder finishes it.

Why 32 macros and not four. Until November 2026 each bank was one
`fakeram_d32768_w36`. CACTI makes that macro 31.2 x 0.22 mm, and its
generated library gives the clock pin a minimum period of 22.08 ns. Setup
slack does not include that check, so the earlier whole-chip synthesis
results at 10 to 12 ns (`timing_10ns.md`, the `upycore_soc*` runs) reported
positive slack on a memory that could not run at those clocks; treat them
as logic-only numbers. A 4096-word macro's minimum period is 1.07 ns.
`deep_reports.tcl` now writes the check to `min_period.rpt`.

Clock tree settings. The class flow's Innovus script asks for a 0.03 ns
skew target with a fanout of 10 and does not optimize clock gates; on the
core alone that gave 1.6 ns of skew, 3.4 ns of insertion delay and 82
failing clock-gate checks at 12 ns. `DESIGN_ARGS=--cts` runs with a 0.15 ns
target, fanout 24 and `opt_clock_gate_aware`. It works through
`upycore_hammer.py`, the class Hammer driver plus one hook that runs the
folder's `cfg/par_settings.tcl` before `place_opt_design`;
`--diodes` turns on antenna diode insertion the same way (the class flow
repairs antennas by rerouting only), `--par-tcl '<line>'` adds any other
Innovus line (not through `DESIGN_ARGS`, which splits on spaces), and
`--set key=value` sets a Hammer key in `cfg.yml` (for example
`par.generate_power_straps_options.by_tracks.power_utilization_met4=0.2`
for more met4 routing room).

Two options for closing timing after routing (any top, via DESIGN_ARGS):
`--syn-margin 1.5` adds 1.5 ns of clock uncertainty in Genus only, so the
netlist keeps slack for the wires (synthesis slack in `status` includes the
margin). Innovus reads only the SDC Genus writes, margin included, so the
option also restores the plain 0.1 ns through `cfg/par_settings.tcl`; runs
before November 11, 2026 that used it were placed and routed with the margin
still on, for setup and hold. And
`--par-effort extreme` sets Hammer's `par.innovus.design_flow_effort`.
