# Extra reports from a finished Hammer synthesis run, at any sky130 corner.
#
# The class flow times synthesis at ss_100C_1v60 (worst case). This reads
# the mapped netlist Hammer wrote and reports area, timing and power at
# another corner (typical by default), with Genus's default switching
# activity. Run it from the design folder after `make syn`:
#
#   genus -batch -files ~/upycore/upycore/synth/hammer/genus_reports.tcl \
#         -execute "set TOP mpy_core; set PERIOD 25"
#
# Optional: set CORNER (default tt_025C_1v80), CLOCK (clk_i), RESET (rst_n_i),
# ALSO_CLOCKS (list of other clock ports), SAIF and SAIF_INSTANCE (activity
# from simulation), LIB_DIR, NETLIST, OUT.
# Reports go to build/extra-reports/<corner>/.

if {![info exists TOP]}    { puts "set TOP first"; exit 1 }
if {![info exists PERIOD]} { puts "set PERIOD (ns) first"; exit 1 }
if {![info exists CORNER]} { set CORNER tt_025C_1v80 }
if {![info exists CLOCK]}  { set CLOCK clk_i }
if {![info exists RESET]}  { set RESET rst_n_i }
if {![info exists LIB_DIR]} {
    set LIB_DIR /home/projects/ee477/cad/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib
}
if {![info exists NETLIST]} { set NETLIST build/syn-rundir/$TOP.mapped.v }
if {![info exists OUT]}     { set OUT build/extra-reports/$CORNER }
file mkdir $OUT

read_libs $LIB_DIR/sky130_fd_sc_hd__$CORNER.lib
read_netlist $NETLIST
current_design $TOP

create_clock -period $PERIOD -name core_clk [get_ports $CLOCK]
# Other clock ports at the same period (Hazard3: clk_always_on).
if {![info exists ALSO_CLOCKS]} { set ALSO_CLOCKS {} }
foreach c $ALSO_CLOCKS { create_clock -period $PERIOD -name $c [get_ports $c] }
set_clock_uncertainty 0.1 [all_clocks]
set_false_path -from [get_ports $RESET]

# Each report is wrapped so one unsupported option does not lose the rest.
proc try_report {name cmd} {
    if {[catch {uplevel 1 $cmd} err]} { puts "WARNING: $name failed: $err" }
}

# Switching activity from simulation (SAIF): power from what a benchmark
# really toggles instead of Genus's default guess. SAIF_INSTANCE is the
# core's path in the testbench. Set PERIOD to the simulated clock period
# (the uPyCore testbench runs at 10 ns), so the toggle rates match.
if {[info exists SAIF]} {
    if {![info exists SAIF_INSTANCE]} { set SAIF_INSTANCE tb_mpy_soc/u_soc/u_core }
    try_report read_saif {read_saif -instance $SAIF_INSTANCE $SAIF}
    try_report saif_annotation {report_sdb_annotation > $OUT/saif_annotation.rpt}
}
# Register-to-register timing only: this is the number Fmax comes from.
try_report timing_reg2reg {report_timing -from [all_registers] -to [all_registers] -max_paths 5 > $OUT/timing_reg2reg.rpt}
try_report timing_all     {report_timing -max_paths 5 > $OUT/timing_all.rpt}
try_report area           {report_area > $OUT/area.rpt}
try_report gates          {report_gates > $OUT/gates.rpt}
try_report power          {report_power > $OUT/power.rpt}
try_report power_hier     {report_power -by_hierarchy -levels 3 > $OUT/power_hier.rpt}
puts "Reports written to $OUT"
exit
