#!/bin/bash
# Run several clock periods of the class flow at once, then list the results.
# Runs survive logging out (nohup), so no tmux is needed.
#
#   sweep.sh collect [periods]  one file ~/par_data/par_<prefix>.txt with the timing,
#                               area, power, constraints and logs of done par runs (plus
#                               deep_reports.tcl output), and a copy of each run's
#                               reports in ~/par_data/<folder>/ (PAR_DATA moves it)
#   sweep.sh start 12 10 8      synthesis only: one folder and one `make syn` per period
#   sweep.sh par 20 15          synthesis, then place and route (`make par`)
#   sweep.sh status             synthesis results of the `start` folders
#   sweep.sh par-status         post-route results of the `par` folders
#
# Folders are $DESIGNS/<prefix>_p<period>: upycore_v2_p12 for `start`,
# upycore_par_p20 for `par` (prefix set by PREFIX). Each run takes a Genus or
# Innovus license and several cores, so start three or four at a time.
#
# The whole chip with its five SRAM macros (four memory banks, the GC table): TOP=mpy_soc sweep.sh start 20 15
# (folders upycore_soc_p20, or upycore_socpar_p20 with `par`) runs `make sram`
# first, with the core from converted/mpy_core.v. SOC_RTL=converted takes the
# whole chip from converted/mpy_soc.v instead. status then also counts the
# macros in each netlist (want 5: 4 x d32768_w36, 1 x d600_w64).
# With `par`, place_macros.py places the five macros and sets the die size
# (DIE is ignored).
# PLACE_ARGS passes place_macros.py options, e.g. PLACE_ARGS="--util 0.4".
#
# Die size: DIE="w h" in um, default 1500 1500 for the core, 4000 3000 for
# the chip. DESIGN_ARGS passes extra make_hammer_design.py options, for example
# DESIGN_ARGS=--no-feedthrough (input-to-output paths are not timed; with the
# class I/O delays of half the period each way they get no time at any clock).
#
# Before starting, the script pulls the current branch and checks that
# converted/*.v were generated from the RTL in this checkout. When the RTL
# changed and they were not regenerated, it stops: run convert_rtl.sh where
# sv2v works (not the lab machines) and push. NO_PULL=1 skips the pull.
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
DESIGNS=${DESIGNS:-$HOME/ee477/ee477-designs-module1}
TOP=${TOP:-mpy_core}
TEMPLATE=${TEMPLATE:-$DESIGNS/pow2}

# Hash of everything converted/*.v is generated from.
rtl_stamp() {
    (cd "$repo" && find upycore/rtl -type f | LC_ALL=C sort |
        xargs cat upycore/tools/mpy_dc_unit.py upycore/tools/mpy_synth.py | sha1sum | cut -d' ' -f1)
}

check_fresh() {
    if [ -z "$NO_PULL" ]; then
        git -C "$repo" pull --ff-only -q || echo "warning: git pull failed; using the checkout as it is"
        # The pull may have changed this script; run the new copy.
        if [ -z "$SWEEP_REEXEC" ]; then SWEEP_REEXEC=1 NO_PULL=1 exec "$0" "$@"; fi
    fi
    want=$(cat "$here/converted/RTL_STAMP" 2>/dev/null || true)
    if [ "$want" != "$(rtl_stamp)" ]; then
        echo "converted/*.v are older than the RTL in $repo/upycore/rtl."
        echo "Regenerate them with convert_rtl.sh (needs sv2v) and push, then run this again."
        exit 1
    fi
    echo "RTL: $(git -C "$repo" log -1 --format='%h %s' 2>/dev/null) (converted files up to date)"
}

launch() {  # launch <prefix> <steps> <periods>...
    prefix=$1 steps=$2
    shift 2
    [ $# -gt 0 ] || { echo "usage: $0 start|par <period ns>..."; exit 1; }
    for p in "$@"; do
        d=$DESIGNS/${prefix}_p$p
        # Never replace a folder whose job is still running: the old Genus or
        # Innovus would keep writing into the new run's files.
        if [ -f "$d/syn.pid" ] && kill -0 "$(cat "$d/syn.pid")" 2>/dev/null; then
            echo "skipped $p ns: $d is still running (pid $(cat "$d/syn.pid")); stop it first or use another PREFIX"
            continue
        fi
        python3 "$here/make_hammer_design.py" "$TEMPLATE" "$d" --top "$TOP" \
            --period "$p" "${src[@]}" ${DESIGN_ARGS:-} --force > /dev/null
        (cd "$d" && { nohup bash -c "$steps" > syn.out 2>&1 & echo $! > syn.pid; })
        echo "started $steps at $p ns in $d (log: $d/syn.out)"
    done
}

state_of() {  # running, done or failed; done means the file $2 exists
    if [ -f "$1/syn.pid" ] && kill -0 "$(cat "$1/syn.pid")" 2>/dev/null; then
        echo running
    elif [ -f "$2" ]; then
        echo done
    else
        echo failed
    fi
}

if [ "$TOP" = mpy_soc ]; then
    sram_macro=$(cd "$repo" && python3 -c "import sys; sys.path.insert(0, 'upycore/tools'); from mpy_synth import SRAM_MACRO, GC_SRAM_MACRO; print(SRAM_MACRO['name'], GC_SRAM_MACRO['name'])")
    syn_prefix=${PREFIX:-upycore_soc}
    par_prefix=${PREFIX:-upycore_socpar}
    if [ "$SOC_RTL" = converted ]; then
        src=(--rtl "$here/converted/mpy_soc.v")
    else
        src=(--core-v "$here/converted/mpy_core.v")
    fi
    src+=(--die ${DIE:-4000 3000})
    syn_steps="make sram && make syn"
    # Place and route: place the macros and size the die from the generated
    # LEFs (place_macros.py) between `make sram` and `make syn`.
    par_steps="make sram && python3 $here/place_macros.py . ${PLACE_ARGS:-} && make syn && make par"
else
    syn_prefix=${PREFIX:-upycore_v2}
    par_prefix=${PREFIX:-upycore_par}
    src=(--rtl "$here/converted/$TOP.v" --die ${DIE:-1500 1500})
    syn_steps="make syn"
    par_steps="make syn && make par"
fi

case "$1" in
rtl-stamp)
    rtl_stamp
    ;;
start)
    check_fresh "$@"
    shift
    launch "$syn_prefix" "$syn_steps" "$@"
    ;;
par)
    check_fresh "$@"
    shift
    launch "$par_prefix" "$par_steps" "$@"
    echo "place and route takes much longer than synthesis; check with: $0 par-status"
    ;;
status)
    printf "%-22s %-8s %10s %10s %10s %12s %7s\n" folder state "slack ns" "path ns" "min ns" "area um2" macros
    for d in "$DESIGNS"/${syn_prefix}_p*; do
        [ -d "$d" ] || continue
        p=${d##*_p}
        rpt=$d/build/syn-rundir/reports/final_time_ss_100C_1v60.setup_view.rpt
        qor=$d/build/syn-rundir/reports/final_qor.rpt
        state=$(state_of "$d" "$qor")
        slack=- path=- minp=- area=- macros=-
        net=$(ls "$d"/build/syn-rundir/*.mapped.v 2>/dev/null | head -1)
        [ "$TOP" = mpy_soc ] && [ -n "$net" ] && macros=$(grep -cwE "$(echo $sram_macro | tr ' ' '|')" "$net" || true)
        if [ "$state" = done ] && [ -f "$rpt" ]; then
            slack=$(awk '/Slack:=/{print $2/1000; exit}' "$rpt")
            path=$(awk '/Data Path:-/{print $3/1000; exit}' "$rpt")
            minp=$(awk -v p="$p" -v s="$slack" 'BEGIN{printf "%.2f", p - s}')
            area=$(awk '/^ *Cell Area/{printf "%.0f", $NF; exit}' "$qor")
        fi
        printf "%-22s %-8s %10s %10s %10s %12s %7s\n" "${d##*/}" "$state" "$slack" "$path" "$minp" "$area" "$macros"
    done
    if [ "$TOP" = mpy_soc ]; then
        for m in $sram_macro; do
            lef=$(find "$DESIGNS"/${syn_prefix}_p* -name "$m.lef" 2>/dev/null | head -1)
            [ -n "$lef" ] && echo "$m footprint (um): $(grep -m1 -o 'SIZE.*' "$lef")"
        done
    fi
    echo "min ns = period - slack: the shortest clock that run's netlist would meet."
    echo "Critical path of one run: awk '/Startpoint/{n++} n==1' <folder>/build/syn-rundir/reports/final_time_ss_100C_1v60.setup_view.rpt | less"
    ;;
par-status)
    printf "%-20s %-8s %9s %9s %9s %9s %12s %s\n" folder state "slack ns" "min ns" "r2r slk" "r2r min" "area um2" "power mW (vectorless)"
    for d in "$DESIGNS"/${par_prefix}_p*; do
        [ -d "$d" ] || continue
        p=${d##*_p}
        run=$d/build/par-rundir
        tim=$run/timingReports/${TOP}_postRoute_all.tarpt.gz
        r2r=$run/timingReports/${TOP}_postRoute_reg2reg.tarpt.gz
        pwr=$run/${TOP}_power.rpt
        are=$run/${TOP}_area.rpt
        state=$(state_of "$d" "$pwr")
        slack=- minp=- rslack=- rminp=- power=- area=-
        # Innovus: "Slack:=   -4.175" on the worst path first, in ns.
        if [ -f "$tim" ]; then
            slack=$(zcat "$tim" | awk '/Slack:=/{print $2; exit}')
            [ -n "$slack" ] && minp=$(awk -v p="$p" -v s="$slack" 'BEGIN{printf "%.2f", p - s}')
        fi
        if [ -f "$r2r" ]; then
            rslack=$(zcat "$r2r" | awk '/Slack:=/{print $2; exit}')
            [ -n "$rslack" ] && rminp=$(awk -v p="$p" -v s="$rslack" 'BEGIN{printf "%.2f", p - s}')
        fi
        [ -f "$pwr" ] && power=$(awk '/^Total Power:/{printf "%.2f", $3; exit}' "$pwr")
        # First data row of report_area: the whole design, total area in column 3.
        [ -f "$are" ] && area=$(awk -v t="$TOP" '$1 == t && $3 ~ /^[0-9.]+$/{printf "%.0f", $3; exit}' "$are")
        printf "%-20s %-8s %9s %9s %9s %9s %12s %s\n" "${d##*/}" "$state" "${slack:--}" "${minp:--}" \
            "${rslack:--}" "${rminp:--}" "${area:--}" "${power:--}"
    done
    echo "Reports: <folder>/build/par-rundir. r2r = register-to-register paths only (no I/O)."
    echo "Power here is Innovus's guess (20% toggle, slow corner); use the SAIF power for the paper."
    echo "Worst path: zcat <reports>/timingReports/${TOP}_postRoute_all.tarpt.gz | less"
    echo "A failed run: tail -50 <folder>/syn.out"
    ;;
collect)
    set +e   # missing reports are normal here; keep going
    # One text file with what an RTL timing review needs from finished par runs.
    # Run deep_reports.tcl in a run's Innovus first for 3000 paths instead of 50.
    data=${PAR_DATA:-$HOME/par_data}
    mkdir -p "$data"
    out=$data/par_${par_prefix}.txt
    shift
    paths() { awk '/Startpoint/{s=$NF} /Endpoint/{e=$NF} /Slack:=/{print $2, s, e}'; }
    full() { awk -v k="$1" '/^ *Path [0-9]+:/{n++} n>=1 && n<=k'; }
    # Group paths by register bank (bit indices and pin dropped): count, worst slack.
    banks() {
        awk '{s=$2; e=$3; sub(/\/[^\/]*$/, "", s); sub(/\/[^\/]*$/, "", e)
              gsub(/\[[0-9]+\]/, "", s); gsub(/\[[0-9]+\]/, "", e)
              k=s " -> " e; c[k]++; if (!(k in w) || $1 < w[k]) w[k]=$1}
             END{for (k in c) print w[k], c[k], k}' | sort -g | head -60
    }
    {
        echo "== sweep.sh collect: $par_prefix, $(date), RTL $(cd "$repo" && git log --oneline -1)"
        echo "== DIE=${DIE:-default} DESIGN_ARGS=${DESIGN_ARGS:-none} (as set for this collect, not necessarily the runs)"
        "$0" par-status
        for d in "$DESIGNS"/${par_prefix}_p*; do
            [ -d "$d" ] || continue
            p=${d##*_p}
            if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$p"; then continue; fi
            run=$d/build/par-rundir
            [ -f "$run/${TOP}_power.rpt" ] || continue
            keep=$data/${d##*/}
            deep=$keep/deep
            # Keep a copy of the run's reports, so they outlive the run folder.
            mkdir -p "$keep/flow"
            cp -p "$run/${TOP}_power.rpt" "$run/${TOP}_area.rpt" "$keep/flow/" 2>/dev/null || true
            mkdir -p "$keep/flow/timingReports"
            cp -p "$run"/timingReports/${TOP}_postRoute_*.tarpt.gz "$keep/flow/timingReports/" 2>/dev/null || true
            find "$d" -maxdepth 3 -name '*.sdc' -exec cp -p {} "$keep/flow/" \; 2>/dev/null || true
            # Only the small summary reports: the full folders are large.
            mkdir -p "$keep/flow/syn_reports"
            cp -p "$d"/build/syn-rundir/reports/final_qor.rpt "$d"/build/syn-rundir/reports/final_area*.rpt \
                "$d"/build/syn-rundir/reports/final_time*setup*.rpt "$keep/flow/syn_reports/" 2>/dev/null || true
            if [ -f "$d/syn.out" ]; then tail -200 "$d/syn.out" > "$keep/flow/syn.out.tail"; fi
            echo; echo "==================== ${d##*/} ===================="
            echo; echo "== constraints (sdc in the run folder)"
            find "$d" -maxdepth 3 -name '*.sdc' -exec sh -c 'echo "-- $1"; grep -v "^ *#" "$1" | grep -v "^ *$"' _ {} \; | head -80
            echo; echo "== timing report files"; ls "$run/timingReports" 2>/dev/null
            for f in "$run"/timingReports/${TOP}_postRoute_*.tarpt.gz; do
                [ -f "$f" ] || continue
                g=${f##*_postRoute_}; g=${g%.tarpt.gz}
                echo; echo "== $g (flow report, 50 paths): slack start end"
                zcat "$f" | paths
            done
            if [ -d "$deep" ]; then
                echo; echo "== deep_reports.tcl output in $deep"; ls "$deep"
                cat "$deep"/*.err 2>/dev/null
                for g in setup r2r hold; do
                    [ -f "$deep/$g.rpt" ] || continue
                    echo; echo "== $g: register banks, worst slack, path count (from up to 3000 endpoints)"
                    paths < "$deep/$g.rpt" | banks
                    echo; echo "== $g: slack start end, worst path per endpoint"
                    paths < "$deep/$g.rpt" | head -600
                done
                [ -f "$deep/r2r.rpt" ] && { echo; echo "== r2r: worst 10 paths in full"; full 10 < "$deep/r2r.rpt"; }
                [ -f "$deep/setup.rpt" ] && { echo; echo "== setup: worst 3 paths in full"; full 3 < "$deep/setup.rpt"; }
                [ -f "$deep/drc.rpt" ] && { echo; echo "== DRC summary"; tail -25 "$deep/drc.rpt"; }
                [ -f "$deep/conn.rpt" ] && { echo; echo "== connectivity"; tail -40 "$deep/conn.rpt"; }
                for g in clock_trees skew_groups route density power_hier; do
                    [ -f "$deep/$g.rpt" ] && { echo; echo "== $g"; head -200 "$deep/$g.rpt"; }
                done
            else
                f=$run/timingReports/${TOP}_postRoute_reg2reg.tarpt.gz
                [ -f "$f" ] && { echo; echo "== reg2reg: worst 5 paths in full"; zcat "$f" | full 5; }
                echo; echo "(no $deep: source deep_reports.tcl in this run's Innovus for 3000 paths, hold, DRC, clock tree)"
                [ -f "$keep/drc.rpt" ] && { echo; echo "== DRC summary"; tail -25 "$keep/drc.rpt"; }
            fi
            echo; echo "== area by module"; head -120 "$run/${TOP}_area.rpt"
            echo; echo "== power"; head -200 "$run/${TOP}_power.rpt"
            echo; echo "== Innovus log: density, congestion, clock tree, final timing lines"
            ls -t "$run"/*.log 2>/dev/null | head -1 | xargs -r grep -h -i -E \
                'density|overflow|congest|skew|WNS|TNS|DRV|utiliz' 2>/dev/null | tail -120
            syn=$d/build/syn-rundir/reports
            if [ -d "$syn" ]; then
                echo; echo "== Genus reports: files"; ls "$syn"
                [ -f "$syn/final_qor.rpt" ] && { echo; echo "== Genus final_qor"; cat "$syn/final_qor.rpt"; }
                for f in "$syn"/*area*; do
                    [ -f "$f" ] && { echo; echo "== Genus ${f##*/}"; head -120 "$f"; }
                done
            fi
        done
    } > "$out" 2>&1
    echo "wrote $out ($(wc -c < "$out") bytes); upload that one file"
    echo "copies of each run's reports are in $data/<folder>/flow (deep reports in .../deep)"
    ;;
*)
    sed -n '2,30p' "$0"
    exit 1
    ;;
esac
