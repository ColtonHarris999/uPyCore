#!/usr/bin/env bash
# Run dc_synth.tcl at several clock periods and tabulate area and slack.
# The smallest period with slack >= 0 gives Fmax = 1000 / period MHz.
#
#   LIB_DB=/path/sky130_fd_sc_hd__tt_025C_1v80.db \
#     upycore/synth/dc/dc_sweep.sh mpy_core 20 15 12 10 8
#
# Other dc_synth.tcl variables (SRC, CLK_PORT, ...) pass through the
# environment. Runs one period at a time so it uses one license.
set -euo pipefail

TOP=${1:?usage: dc_sweep.sh TOP PERIOD_NS...}
shift
[ $# -gt 0 ] || { echo "give at least one period in ns" >&2; exit 1; }

HERE=$(cd "$(dirname "$0")" && pwd)
CSV=build/dc/$TOP/sweep.csv
mkdir -p "build/dc/$TOP"
[ -f "$CSV" ] || echo "period_ns,fmax_mhz,total_area_um2,seq_area_um2,wns_ns,total_power" > "$CSV"

for p in "$@"; do
    out=build/dc/$TOP/$p
    mkdir -p "$out"
    echo "== $TOP @ ${p} ns =="
    TOP=$TOP CLK_NS=$p OUT=$out dc_shell -f "$HERE/dc_synth.tcl" > "$out/dc.log" 2>&1 \
        || { echo "dc_shell failed, see $out/dc.log"; continue; }
    area=$(awk '/Total cell area:/ {print $4; exit}' "$out/area.rpt")
    seq=$(awk '/Noncombinational area:/ {print $3; exit}' "$out/area.rpt")
    # Worst slack over every path group.
    wns=$(awk '/Critical Path Slack:/ {if (!n++ || $4 < m) m = $4} END {print m}' "$out/qor.rpt")
    pwr=$(awk '/^Total / {print $(NF-1) $NF; exit}' "$out/power_summary.rpt")
    fmax=$(awk -v p="$p" 'BEGIN {printf "%.1f", 1000 / p}')
    echo "$p,$fmax,$area,$seq,$wns,$pwr" | tee -a "$CSV"
done
echo "Table: $CSV"
