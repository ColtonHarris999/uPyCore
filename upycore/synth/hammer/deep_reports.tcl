# Extra post-route reports for an RTL timing review. In the Innovus console
# of a finished run (make open-chip in its folder):
#     source ~/upycore/upycore/synth/hammer/deep_reports.tcl
# It writes ~/par_data/<folder>/deep/ (a few minutes; PAR_DATA moves
# ~/par_data); sweep.sh collect then folds those files into
# ~/par_data/par_<prefix>.txt. A command this Innovus does not have
# is skipped and noted in <name>.err; the rest still run.
if {[info exists env(PAR_DATA)]} { set deep_root $env(PAR_DATA) } else { set deep_root $env(HOME)/par_data }
set deep_dir $deep_root/[file tail [file dirname [file dirname [file normalize [pwd]]]]]/deep
file mkdir $deep_dir
proc deep_try {name cmd} {
    global deep_dir
    puts "deep_reports: $name"
    if {[catch {uplevel #0 $cmd} err]} {
        puts "deep_reports: $name failed: $err"
        set f [open $deep_dir/$name.err w]; puts $f $err; close $f
    }
}
deep_try setup   {report_timing -max_paths 3000 -nworst 1 > $deep_dir/setup.rpt}
deep_try r2r     {report_timing -from [all_registers] -to [all_registers] -max_paths 3000 -nworst 1 > $deep_dir/r2r.rpt}
deep_try hold    {report_timing -early -max_paths 300 -nworst 1 > $deep_dir/hold.rpt}
deep_try drc     {check_drc -limit 100000 -out_file $deep_dir/drc.rpt}
deep_try conn    {check_connectivity > $deep_dir/conn.rpt}
deep_try clock   {report_clock_trees > $deep_dir/clock_trees.rpt}
deep_try skew    {report_skew_groups > $deep_dir/skew_groups.rpt}
deep_try route   {report_route -summary > $deep_dir/route.rpt}
deep_try density {report_density > $deep_dir/density.rpt}
deep_try power   {report_power -hierarchy all > $deep_dir/power_hier.rpt}
# Clock-gate enable checks (82 failed in the 12 ns core run), the macros'
# minimum clock period (not part of setup slack), congestion, pin locations.
deep_try clock_gating {report_timing -check_type clock_gating_setup -max_paths 200 -nworst 1 > $deep_dir/clock_gating.rpt}
deep_try min_period   {report_constraint -check_type {clock_period pulse_width} -all_violators > $deep_dir/min_period.rpt}
deep_try congestion   {report_congestion -hotspot > $deep_dir/congestion.rpt}
deep_try ports        {report_ports > $deep_dir/ports.rpt}
puts "deep_reports: done, wrote $deep_dir"
