# Design Compiler flow

These scripts produce area, Fmax and power numbers for uPyCore with Synopsys
Design Compiler (DC), for example with the sky130 `sky130_fd_sc_hd` library
on the UW ECE lab machines.

## Steps

1. Write single-file sources (any machine with Python 3):

   ```sh
   make dc-src            # build/dc/mpy_alu.sv, mpy_decode.sv, mpy_container.sv, mpy_core.sv
   ```

   The RTL shares localparams and functions through file-scope `` `include``
   of `.svh` headers, so each top must be one compilation unit.
   `upycore/tools/mpy_dc_unit.py` concatenates the top's files (the lists in
   `upycore/tools/mpy_synth.py`), inlines every include, and defines
   `SYNTHESIS`. The outputs have been checked to elaborate without errors
   in slang.

2. Point at the library. DC needs a `.db`. If the class gives you only
   `.lib` files, convert one with Library Compiler:

   ```sh
   lc_shell -x 'read_lib sky130_fd_sc_hd__tt_025C_1v80.lib; \
                write_lib sky130_fd_sc_hd__tt_025C_1v80 -format db \
                  -output sky130_fd_sc_hd__tt_025C_1v80.db; exit'
   export LIB_DB=$PWD/sky130_fd_sc_hd__tt_025C_1v80.db
   ```

3. Run one top at one clock (from the repo root):

   ```sh
   TOP=mpy_alu CLK_NS=20 dc_shell -f upycore/synth/dc/dc_synth.tcl | tee dc.log
   ```

   Reports land in `build/dc/<top>/<period>/`: `area.rpt` (per module),
   `qor.rpt`, `timing.rpt`, `power.rpt`, plus the netlist and `.sdc`.

4. Find Fmax with a clock sweep:

   ```sh
   upycore/synth/dc/dc_sweep.sh mpy_core 20 15 12 10 8
   ```

   It appends one row per period to `build/dc/mpy_core/sweep.csv`. The
   smallest period whose worst slack is >= 0 is the Fmax.

## What to synthesize

- `mpy_core`: the processor (ALU, FPU and decoder included). This is the
  headline number.
- `mpy_alu`, `mpy_decode`, `mpy_container`: smaller and quicker; start with
  `mpy_alu` to shake out tool problems.
- **Not** `mpy_mem` or `mpy_soc`: the SRAM and flash are plain arrays
  (768 KiB) and would become millions of flip-flops. Report memory area
  separately from SRAM macros.
- `mpy_gc` needs care: its allocation table relies on powering up as zero
  under `SYNTHESIS` (no initial block), and it holds about 28k bits at the
  default pool size. Treat it as memory, or shrink the pool for a logic-only
  number.

## A baseline core

The same script runs other RTL. For Hazard3, something like:

```sh
TOP=hazard3_core FORMAT=verilog INC=/path/Hazard3/hdl \
  SRC="$(cat file list of Hazard3/hdl ...)" CLK_PORT=clk RST_PORT=rst_n \
  upycore/synth/dc/dc_sweep.sh hazard3_core 20 15 12 10
```

Check the port names and file list against the Hazard3 checkout. Use the
same library, constraints and sweep for both cores so the comparison is fair.

## Power

`report_power` here uses DC's default switching activity, so it is an
estimate. For a benchmark-based number, simulate the netlist with the
benchmark, dump SAIF, add `read_saif -input run.saif -instance <tb path>`
before `report_power`, and say which benchmark the activity came from.
