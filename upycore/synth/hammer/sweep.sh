#!/bin/bash
# Clock sweep: synthesize mpy_core at several periods at once, then list the
# result of each. Runs survive logging out (nohup), so no tmux is needed.
#
#   sweep.sh start 12 10 8      one design folder and one `make syn` per period
#   sweep.sh status             every folder: running or done, slack, min period
#
# Folders are $DESIGNS/$PREFIX_p<period> (default
# ~/ee477/ee477-designs-module1/upycore_v2_p12 ...). Each run takes one Genus
# license and several cores, so start three or four at a time.
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
DESIGNS=${DESIGNS:-$HOME/ee477/ee477-designs-module1}
PREFIX=${PREFIX:-upycore_v2}
TOP=${TOP:-mpy_core}
RTL=${RTL:-$here/converted/$TOP.v}
TEMPLATE=${TEMPLATE:-$DESIGNS/pow2}

case "$1" in
start)
    shift
    [ $# -gt 0 ] || { echo "usage: $0 start <period ns>..."; exit 1; }
    for p in "$@"; do
        d=$DESIGNS/${PREFIX}_p$p
        python3 "$here/make_hammer_design.py" "$TEMPLATE" "$d" --top "$TOP" \
            --period "$p" --rtl "$RTL" --force > /dev/null
        (cd "$d" && { nohup make syn > syn.out 2>&1 & echo $! > syn.pid; })
        echo "started $p ns in $d (log: $d/syn.out)"
    done
    ;;
status)
    printf "%-22s %-8s %10s %10s %10s %12s\n" folder state "slack ns" "path ns" "min ns" "area um2"
    for d in "$DESIGNS"/${PREFIX}_p*; do
        [ -d "$d" ] || continue
        p=${d##*_p}
        rpt=$d/build/syn-rundir/reports/final_time_ss_100C_1v60.setup_view.rpt
        qor=$d/build/syn-rundir/reports/final_qor.rpt
        if [ -f "$d/syn.pid" ] && kill -0 "$(cat "$d/syn.pid")" 2>/dev/null; then
            state=running
        elif grep -q "Normal exit" "$d/syn.out" 2>/dev/null; then
            state=done
        else
            state=failed
        fi
        slack=- path=- minp=- area=-
        if [ "$state" = done ] && [ -f "$rpt" ]; then
            slack=$(awk '/Slack:=/{print $2/1000; exit}' "$rpt")
            path=$(awk '/Data Path:-/{print $3/1000; exit}' "$rpt")
            minp=$(awk -v p="$p" -v s="$slack" 'BEGIN{printf "%.2f", p - s}')
            area=$(awk '/^ *Cell Area/{printf "%.0f", $NF; exit}' "$qor")
        fi
        printf "%-22s %-8s %10s %10s %10s %12s\n" "${d##*/}" "$state" "$slack" "$path" "$minp" "$area"
    done
    echo "min ns = period - slack: the shortest clock that run's netlist would meet."
    echo "Critical path of one run: awk '/Startpoint/{n++} n==1' <folder>/build/syn-rundir/reports/final_time_ss_100C_1v60.setup_view.rpt | less"
    ;;
*)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
