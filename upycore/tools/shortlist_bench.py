#!/usr/bin/env python3
"""Capture kernel cycles/results for a pinned simulator; compare identical cases.

This runner does not substitute CPython for the pinned oracle: --compare checks
the captured baseline's result callbacks, and reports their limited coverage.
"""
import argparse
import concurrent.futures
import hashlib
import json
import subprocess
from pathlib import Path
import mpy_build as b
from perf_inventory import HARNESS

CASES = 'bm_chaos,bm_fannkuch,bm_fft,bm_float,bm_hexiom,bm_nqueens,bm_wordcount,core_locals,core_qstr,core_str,core_yield_from,misc_aes,misc_mandel,misc_pystone,misc_raytrace'

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--sim', type=Path, default=b.SIM)
    ap.add_argument('--cases', default=CASES)
    ap.add_argument('--flags', default='+CA=1 +AALU=1')
    ap.add_argument('--compare', type=Path)
    ap.add_argument('--workers', type=int, default=3)
    args = ap.parse_args()
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
    fw = out/'bench_fw.py'; fm = out/'bench_fw.mpy'
    fw.write_text(b.firmware_source()+'\ndef bench_ticks():\n    return _ticks()\n')
    b.mpy_cross(fw, fm, '_fw.py'); b.build_firmware = lambda: fm
    b.frozen_runtime_specs(compiler=False, runtime=sorted(b.RUNTIME_MODULES))
    cases = []
    for name in args.cases.split(','):
        src = b.ROOT/'vendor/micropython/tests/perf_bench'/f'{name}.py'
        work = out/name; work.mkdir(exist_ok=True)
        prog = work/src.name; prog.write_text(src.read_text()+HARNESS.format(n=100,m=100))
        image = b.build_program(prog, work, source_name=src.name)
        cases.append((name,image,sha(prog),sha(str(image)+'.hex')))
    data = {'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=b.ROOT,text=True).strip(),
            'simulator_sha256':sha(args.sim), 'firmware_sha256':sha(fm),
            'compiler_sha256':sha(b.MPY_CROSS), 'flags':args.flags.split(),
            'boundary':'bench_ticks around run(), N=100 M=100', 'clock_period_ns':18,
            'validation':'baseline result callback comparison; not an independent oracle run', 'rows':[]}
    baseline = {r['name']:r for r in json.loads(args.compare.read_text())['rows']} if args.compare else {}
    def one(case):
        name,image,source_hash,image_hash = case
        r = b.run_image(image, sim_executable=args.sim.resolve(), max_cycles=500_000_000,
                        timeout=12000, sim_args=data['flags'])
        (image.parent/'sim.log').write_text(r.log)
        lines = r.stdout.decode().splitlines()
        cycles = next((int(x.split()[1]) for x in lines if x.startswith('CYCLES ')),None)
        result = next((x for x in lines if x.startswith('RESULT ')),None)
        row = dict(name=name,cycles=cycles,result=result,halt=r.halt,gc=r.gc,
                   total_cycles=r.cycles,source_sha256=source_hash,image_sha256=image_hash,
                   stderr=r.stderr.decode(),ok=r.exit_code==0 and not r.stderr and cycles is not None and result is not None)
        if baseline:
            old=baseline[name]
            row['ok'] &= old['ok'] and old['source_sha256']==source_hash and old['result']==result
            if cycles is not None and old['cycles']:
                row['cycle_change_percent']=100*(cycles/old['cycles']-1)
        return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for row in pool.map(one,cases):
            data['rows'].append(row)
            (out/'results.json').write_text(json.dumps(data,indent=2)+'\n')
            print(row['name'],row['cycles'],row['ok'],row.get('cycle_change_percent',''),flush=True)
    return int(any(not r['ok'] for r in data['rows']))

if __name__=='__main__':
    raise SystemExit(main())
