#!/usr/bin/env python3
"""Render saved phase-0 evidence; never resimulates or rewrites measurements."""
import argparse,csv,json,math
from pathlib import Path

def fit(points):
    n=len(points);mx=sum(x for x,y in points)/n;my=sum(y for x,y in points)/n
    slope=sum((x-mx)*(y-my) for x,y in points)/sum((x-mx)**2 for x,y in points)
    intercept=my-slope*mx
    ss=sum((y-my)**2 for x,y in points);err=sum((y-(intercept+slope*x))**2 for x,y in points)
    return intercept,slope,1-err/ss if ss else 1

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=Path('build'))
    ap.add_argument('--out',type=Path,required=True);args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    datasets={name:json.loads((args.root/('phase0-'+name)/'results.json').read_text()) for name in ['kernels','micro-on','micro-off','project']}
    for name,data in datasets.items():(args.out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
    lines=['# Phase 0: runtime attribution and reproducible baseline','',
           'The benchmark branch starts from main `5b554513c816bd4f28d519ea55c449ae4a22092f`. No synthesized RTL or production firmware was changed. Instrumentation is a passive testbench include enabled only with `MPY_PROFILE`. This is a profiling baseline, not an optimization result.','',
           '## Baseline reproduction and passivity','',
           'Both executables consume each exact same linked image. The reference executable is the retained plain simulator from the earlier benchmark run. The profiled simulator was rebuilt from the same RTL with Verilator 5.020. All measured kernel cycles and result checks must match between the two executables; groups, reasons, self functions, state counters and group/reason cross-tabs must each sum to the timed interval.','',
           '| Kernel | Reference cycles | Profiled cycles | Time at assumed 18 ns | GC requests |',
           '|---|---:|---:|---:|---:|']
    kernels=datasets['kernels']['rows']
    for r in kernels:
        assert r['reference']['cycles']==r['profiled']['cycles']
        p=r['profile'];assert p['cycles']==p['stop']-p['start'];assert not p['ancestry_warnings']
        lines.append(f"| {r['name']} | {r['reference']['cycles']:,} | {r['profiled']['cycles']:,} | {r['time_ms_18ns']:.3f} ms | {p['events'].get('collection_requests',0)} |")
    lines+=['','## Exclusive semantic attribution','',
            'A cycle belongs to the nearest monitored helper on its current coherent frame ancestry. Nested monitored helpers get their own bucket, so these categories partition rather than overlap. Ordinary firmware helpers inherit their monitored caller. Bytearray load/store groups originate from actual scalar bytearray hook admissions. Restoration cycles with temporarily incoherent frame metadata have their own bucket. These are observations, not counterfactual speedup estimates.','',
            '| Category | AES cycles | AES % | Fannkuch cycles | Fannkuch % |','|---|---:|---:|---:|---:|']
    by={r['name']:r for r in kernels};aes=by['misc_aes']['profile'];fann=by['bm_fannkuch']['profile']
    for group in aes['groups']:
        a=aes['groups'][group];f=fann['groups'][group]
        if a or f:lines.append(f"| {group} | {a:,} | {100*a/aes['cycles']:.2f}% | {f:,} | {100*f/fann['cycles']:.2f}% |")
    lines+=['','## Exclusive execution reasons','',
            'Reason priority is allocator wait, GC states, data-memory wait (scoreboard before grant before response), empty instruction fetch, native service, call/frame service, AALU service, execute. Memory waits inside native/frame helpers are counted as memory waits, not again as service. Grant/response attribution describes core FSM/port observations, not SRAM latency alone. Background accelerator busy time is not automatically a core stall.','',
            '| Reason | AES cycles | Fannkuch cycles |','|---|---:|---:|']
    for reason in aes['reasons']:
        a=aes['reasons'][reason];f=fann['reasons'][reason]
        if a or f:lines.append(f'| {reason} | {a:,} | {f:,} |')
    for r in kernels:
        p=r['profile'];lines+=['',f"## {r['name']}: monitored inclusive functions",'',
            'Inclusive function cycles contain descendants and therefore overlap. Frame restoration is excluded; the next coherent frame establishes a new ancestry snapshot. Recursive occurrences are counted once per function. Outer `_boot` and module wrappers are omitted below, but retained in JSON. Do not sum this table.','',
            '| Function | Self cycles | Inclusive cycles | Entries inside interval |','|---|---:|---:|---:|']
        monitored=['_subscr','_setsubscr','_getslice','_slice_range','_slice_len','_list_setslice','_list_of_iter','_list_of_seq','_newlist','_list_reserve','list__pop','list__insert']
        for n in monitored:
            row=p['functions'].get('_fw:'+n)
            if row:lines.append(f"| {n} | {row['self_cycles']:,} | {row['inclusive_cycles']:,} | {row['entries']:,} |")
        lines+=['','Events: '+', '.join(f'{k}={v:,}' for k,v in p['events'].items())+'.']
    records=[];micro={}
    for mode in ['on','off']:
        data=datasets['micro-'+mode];micro[mode]={r['name']:r for r in data['rows']}
        for r in data['rows']:
            assert r['reference']['cycles']==r['profiled']['cycles']
            kind,n,typ=r['name'].rsplit('_',2)
            records.append({'case':kind,'length':int(n),'elements':typ,'ca':mode,'loops':data['micro_loops'],
                            'cycles':r['profiled']['cycles'],'cycles_per_invocation':r['profiled']['cycles']/data['micro_loops'],
                            'gc_requests':r['profile']['events']['collection_requests']})
    with (args.out/'curves.csv').open('w') as f:
        writer=csv.DictWriter(f,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
    lines+=['','## Microbenchmark curves','',
            'Lengths: 0, 1, 2, 4, 6, 8, 16, 32, 64, 256, 1024. Integer and mixed-tag lists are separate cases; the mixed palette includes None, float, bool, string, tuple and a mutable list. CA on/off is measured with AALU on. Setup and result printing are outside the kernel. Each point uses one deterministic invocation, including loop/call/timer overhead; this is not a warmed steady-state throughput test. Full output values match CPython.','',
            f"Completed {len(records)} microbenchmark measurements; each also has a matched plain-simulator run. Raw values are in curves.csv and the two micro JSON files. Control-loop timings are retained, not silently subtracted.",'',
            'The following fits use n=1..256, integer cases, CA on: cycles = intercept + slope × n. Fits are descriptive, include fixed Python overhead, and may cross allocator/cache/bank boundaries; do not use an extrapolated intersection as an accelerator-dispatch threshold.','',
            '| Operation | Intercept, cycles | Slope, cycles/element | R² |','|---|---:|---:|---:|']
    for kind in ['byte_read','byte_write','list_copy','reverse_slice','slice_assign','pop_insert']:
        pts=[(r['length'],r['cycles_per_invocation']) for r in records if r['case']==kind and r['elements']=='int' and r['ca']=='on' and 1<=r['length']<=256]
        a,b,r2=fit(pts);lines.append(f'| {kind} | {a:.1f} | {b:.2f} | {r2:.4f} |')
    lines+=['','| Operation | N | CA on cycles | CA off cycles | Off/on |','|---|---:|---:|---:|---:|']
    for kind in ['list_copy','reverse_slice','slice_assign','pop_insert']:
        for n in [1,6,64,1024]:
            key=f'{kind}_{n}_int';a=micro['on'][key]['profiled']['cycles'];b=micro['off'][key]['profiled']['cycles']
            lines.append(f'| {kind} | {n} | {a:,} | {b:,} | {b/a:.3f}× |')
    project=datasets['project']['rows'];assert len(project)==11 and all(len(r['runs'])==4 for r in project)
    lines+=['','## Original project suite regression','',
            'All 11 original programs use production firmware, unchanged sources and all four accelerator combinations. Every mode compares stdout/stderr across configurations and compares the plain simulator with the profile-capable build with profiling disabled. This is 44 logical configurations and 88 simulator executions. Counts below are whole-program core cycles, unlike the kernel-only measurements above.','',
            '| Program | Off | CA | AALU | Both |','|---|---:|---:|---:|---:|']
    for r in project:lines.append('| '+r['name']+' | '+' | '.join(f"{run['profile_disabled']['cycles']:,}" for run in r['runs'])+' |')
    lines+=['','## Reproduction','',
            'Build the pinned mpy-cross (`variants/upycore/build.sh mpy-cross`). Install Verilator and a C++ toolchain. From the repository root:','',
            '```bash',
            'python3 upycore/tools/runtime_profile.py --out build/phase0-kernels --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile.py --micro --loops 1 --out build/phase0-micro-on --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile.py --micro --loops 1 --ca 0 --out build/phase0-micro-off --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile.py --project-suite --out build/phase0-project --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile_report.py --root build --out build/phase0-report',
            'python3 -m unittest discover -s upycore/tools -p test_runtime_profile.py',
            '```','',
            'Build the plain simulator in a separate checkout at the recorded main commit with mpy_build.py sim, without MPY_PROFILE. Keep its executable unchanged. For a later RTL candidate, reuse the baseline firmware/program images; do not silently compare different images. Future firmware optimizations require explicitly labeled image changes and matching workload/output checks. The --before comparison validates equal images on two executables; it is not evidence of an optimization speedup.','',
            'Metadata includes RTL and firmware source hashes, MicroPython/compiler versions, simulator/compiler hashes, image hashes, accelerator flags, parameter/harness hashes and raw result checks. The evidence archive retains raw profiler records, logs and kernel images/maps. Measurement metadata identifies the main design commit plus the dirty testbench diff captured during tool development; the benchmark-branch commits contain the finalized tools. The synthesized RTL hashes match main.','',
            '## Limitations and next gate','',
            'Profiling has no hardware timing or power result. Runtime at 18 ns is an assumption. Simulator wall time is not hardware execution time. Inclusive function totals exclude restoration and overlap; semantic groups inherit the nearest monitored ancestor. No AES or list optimization is implemented here. The prior wordcount/core_locals failures remain separate defects; this phase does not rerun or reclassify the full upstream inventory.','',
            'Use the bytearray groups and their subscript inclusive counts to size phase 1. Use normalized-slice, reverse-copy, RHS-materialization and list-method costs to prioritize the remaining work. The measured CA on/off curves establish current overheads, but do not predict a crossover for an unimplemented native core loop or strided engine.','']
    (args.out/'README.md').write_text('\n'.join(lines))

if __name__=='__main__':main()
