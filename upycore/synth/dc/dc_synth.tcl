# Design Compiler synthesis for one uPyCore top (or any other design).
#
# Settings come from environment variables so one script serves every top
# and every clock period:
#
#   LIB_DB     path to the standard-cell .db (required), for example
#              .../sky130_fd_sc_hd__tt_025C_1v80.db
#   TOP        top module (default mpy_core)
#   SRC        source files, space separated (default build/dc/$TOP.sv,
#              written by `make dc-src`)
#   FORMAT     sverilog or verilog (default sverilog)
#   INC        extra include directories, space separated
#   DEFINES    macros for analyze -define, space separated
#   CLK_NS     clock period in ns (default 20)
#   CLK_PORT   clock port (default clk_i)
#   RST_PORT   async reset port (default rst_n_i; empty for none)
#   OUT        report directory (default build/dc/$TOP/$CLK_NS)
#
# Run from the repo root:  dc_shell -f upycore/synth/dc/dc_synth.tcl

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set TOP      [env_or TOP mpy_core]
set LIB_DB   [env_or LIB_DB ""]
set SRC      [env_or SRC "build/dc/$TOP.sv"]
set FORMAT   [env_or FORMAT sverilog]
set INC      [env_or INC ""]
set DEFINES  [env_or DEFINES ""]
set CLK_NS   [env_or CLK_NS 20]
set CLK_PORT [env_or CLK_PORT clk_i]
set RST_PORT [env_or RST_PORT rst_n_i]
set OUT      [env_or OUT "build/dc/$TOP/$CLK_NS"]

if {$LIB_DB eq "" || ![file exists $LIB_DB]} {
    puts "Error: set LIB_DB to the standard-cell .db file (got '$LIB_DB')"
    exit 1
}
foreach f $SRC {
    if {![file exists $f]} {
        puts "Error: source $f not found (for uPyCore tops run `make dc-src` first)"
        exit 1
    }
}

file mkdir $OUT
set_app_var target_library [list $LIB_DB]
set_app_var link_library   [concat * $LIB_DB]
set_app_var search_path    [concat . $INC $search_path]
define_design_lib WORK -path $OUT/work

# ---- Read and elaborate -------------------------------------------------
if {$DEFINES ne ""} {
    analyze -format $FORMAT -define $DEFINES $SRC
} else {
    analyze -format $FORMAT $SRC
}
elaborate $TOP
current_design $TOP
link
check_design > $OUT/check_design.rpt

# ---- Constraints ----------------------------------------------------------
create_clock -name clk -period $CLK_NS [get_ports $CLK_PORT]
set_clock_uncertainty [expr {0.05 * $CLK_NS}] [get_clocks clk]

set skip [list $CLK_PORT]
if {$RST_PORT ne ""} {
    lappend skip $RST_PORT
    # Reset is a static net at this level; don't time or buffer it here.
    set_ideal_network [get_ports $RST_PORT]
    set_false_path -from [get_ports $RST_PORT]
}
set data_in [remove_from_collection [all_inputs] [get_ports $skip]]
set_input_delay  [expr {0.2 * $CLK_NS}] -clock clk $data_in
set_output_delay [expr {0.2 * $CLK_NS}] -clock clk [all_outputs]
# Library capacitance unit is pF for sky130.
set_load 0.005 [all_outputs]

# ---- Compile ---------------------------------------------------------------
# Keep hierarchy so report_area -hierarchy gives a per-module breakdown.
compile_ultra -no_autoungroup

# ---- Reports ---------------------------------------------------------------
report_qor                          > $OUT/qor.rpt
report_area -hierarchy              > $OUT/area.rpt
report_timing -max_paths 10 -nets   > $OUT/timing.rpt
report_power -hierarchy             > $OUT/power.rpt
report_power                        > $OUT/power_summary.rpt
report_reference -hierarchy         > $OUT/reference.rpt
report_constraint -all_violators    > $OUT/violators.rpt

write -format ddc -hierarchy -output $OUT/$TOP.ddc
write -format verilog -hierarchy -output $OUT/$TOP.netlist.v
write_sdc $OUT/$TOP.sdc

puts "Reports in $OUT"
exit
