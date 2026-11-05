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
    a=next(r['profile'] for r in kernels if r['name']=='misc_aes')
    f=next(r['profile'] for r in kernels if r['name']=='bm_fannkuch')
    bytecycles=a['groups']['bytearray_load']+a['groups']['bytearray_store']
    slicecycles=sum(f['functions']['_fw:'+name]['inclusive_cycles'] for name in ['_getslice','_list_setslice'])
    lines+=['','## Main findings','',
            f"- AES: bytearray load/store firmware groups consume {bytecycles:,} cycles ({100*bytecycles/a['cycles']:.2f}%). The 5,544 read and 3,528 write admissions exactly match the independent workload counts. There are no allocation/GC requests or bulk-copy commands in the timed region. Scalar access is the first target.",
            f"- Fannkuch: slice creation and assignment have {slicecycles:,} inclusive cycles ({100*slicecycles/f['cycles']:.2f}%), excluding restoration. The exclusive normalization group is {100*f['groups']['slice_normalize']/f['cycles']:.2f}%. The redundant RHS materialization path (_list_of_iter inclusive) costs {f['functions']['_fw:_list_of_iter']['inclusive_cycles']:,} cycles. Pop and insert remain useful, but are smaller targets.",
            '- Neither kernel records a scoreboard stall or copy-admission stall. This does not imply zero accelerator activity: Fannkuch issues thousands of commands, but firmware work hides their latency. Faster bulk memory alone will not remove Python dispatch and normalization costs.',
            '- These are current costs, not guaranteed removable cycles. A fast path still needs bounds, type and lifetime checks. Inclusive counts overlap where noted; do not add arbitrary percentages or treat them as measured speedups.','']
    probe=args.root/'phase0-bytes-probe'/'results.json'
    if probe.exists():
        probe_data=json.loads(probe.read_text());(args.out/'bytes-probe.json').write_text(json.dumps(probe_data,indent=2)+'\n')
        lines+=['','### Additional immutable-bytes fast-path finding','',
                'The scalar bytes load path checks si_na before extracting a byte. S_SINFO carries the non-ASCII metadata bit for bytes as well as text. Thus bytes containing high-bit values can take a text-oriented fallback even though integer byte indexing needs no Unicode interpretation. A four-read probe confirms the behavior:','',
                '| Probe | Kernel cycles | _subscr entries |','|---|---:|---:|']
        for r in probe_data['rows']:
            entries=r['profile']['functions'].get('_fw:_subscr',{}).get('entries',0)
            lines.append(f"| {r['name']} | {r['profiled']['cycles']:,} | {entries} |")
        lines+=['','AES has 6,992 _subscr entries: 5,544 bytearray reads plus 1,448 other reads. The 1,448 remainder matches its S-box lookup count. Combined with the probe and guard inspection, this identifies immutable S-box reads as an additional phase-1 target. This attribution to S-box reads is inferred from matching counts and code paths; the generic group itself is directly measured at 6,345,136 cycles (10.65%). No guard or runtime behavior is changed in phase 0.','']
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
            'Lengths: 0, 1, 2, 4, 6, 8, 16, 32, 64, 256, 1024. Integer and mixed-tag lists are separate cases; the mixed palette includes None, float, bool, string, tuple and a mutable list. CA on/off is measured with AALU on. Setup and result printing are outside the kernel. Each point uses one deterministic invocation, including loop/call/timer overhead; this is not a warmed steady-state throughput test. Full output values match CPython. These primary curves measure issue/return latency: asynchronous copies can remain in flight at the second tick, so flat copy timings are not completed-copy throughput.','',
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
    completion={}
    for mode in ['on','off']:
        path=args.root/('phase0-complete-'+mode)/'results.json'
        if path.exists():
            c=json.loads(path.read_text());(args.out/('complete-'+mode+'.json')).write_text(json.dumps(c,indent=2)+'\n')
            completion[mode]={r['name']:r for r in c['rows']}
    if len(completion)==2:
        assert all(len(c)==15 for c in completion.values())
        lines+=['','### Dependent completion probes','',
                'Separate probes force a read of the last copied destination element before stopping the timer. For pop/insert, this is index n-2 of the left-shifted tail (when n>1); the inserted final element alone would not fence that tail. These timings include the dependent read overhead. They prevent issue/return latency from being mistaken for data-ready latency. Both CA modes use the same probe and each is checked against the plain simulator.','',
                '| Operation | N | CA on data-ready cycles | CA off data-ready cycles | On scoreboard waits |','|---|---:|---:|---:|---:|']
        for n in [1,6,64,256,1024]:
            for kind in ['list_copy','slice_assign','pop_insert']:
                name=f'{kind}_{n}_int';a=completion['on'][name];b=completion['off'][name]
                lines.append(f"| {kind} | {n} | {a['profiled']['cycles']:,} | {b['profiled']['cycles']:,} | {a['profile']['reasons']['scoreboard_wait']:,} |")
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
            'python3 upycore/tools/runtime_profile.py --completion-probes --loops 1 --out build/phase0-complete-on --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile.py --completion-probes --loops 1 --ca 0 --out build/phase0-complete-off --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile.py --bytes-probe --out build/phase0-bytes-probe --before /absolute/plain-simulator',
            'python3 upycore/tools/runtime_profile_report.py --root build --out build/phase0-report',
            'python3 upycore/tools/runtime_profile_compare.py build/phase0-kernels/results.json build/candidate/results.json --out build/comparison.json',
            'python3 -m unittest discover -s upycore/tools -p test_runtime_profile.py',
            '```','',
            'Build the plain simulator in a separate checkout at the recorded main commit with mpy_build.py sim, without MPY_PROFILE. Keep its executable unchanged. For a later RTL candidate, reuse the baseline firmware/program images; do not silently compare different images. Future firmware optimizations require explicitly labeled image changes and matching workload/output checks. The --before comparison validates equal images on two executables; it is not evidence of an optimization speedup.','',
            'The runner locks each output directory to reject overlapping jobs. --resume reuses only validated rows whose images/settings and executable hashes remain compatible; continuation metadata is retained. An empty microbenchmark profile capture was rejected and that point was rerun; no invalid or exploratory capture is included in the published results. The initial tool-source git bundle and initial captured patches preserve local design/tool provenance; intermediate runner revisions are not all archived. Exact executed harnesses and kernel images are retained, with hashes for the other images.','',
            'Metadata includes RTL and firmware source hashes, MicroPython/compiler versions, simulator/compiler hashes, image hashes, accelerator flags, parameter/harness hashes and raw result checks. The evidence archive retains raw profiler records, logs and kernel images/maps. Measurement metadata identifies the main design commit plus the dirty testbench diff captured during tool development; the benchmark-branch commits contain the finalized tools. The synthesized RTL hashes match main.','',
            '## Limitations and next gate','',
            'Profiling has no hardware timing or power result. Runtime at 18 ns is an assumption. Simulator wall time is not hardware execution time. Inclusive function totals exclude restoration and overlap; semantic groups inherit the nearest monitored ancestor. No AES or list optimization is implemented here. The prior wordcount/core_locals failures remain separate defects; this phase does not rerun or reclassify the full upstream inventory.','',
            'Use the bytearray groups and their subscript inclusive counts to size phase 1. Use normalized-slice, reverse-copy, RHS-materialization and list-method costs to prioritize the remaining work. The measured CA on/off curves establish current overheads, but do not predict a crossover for an unimplemented native core loop or strided engine.','']
    (args.out/'README.md').write_text('\n'.join(lines))

if __name__=='__main__':main()
