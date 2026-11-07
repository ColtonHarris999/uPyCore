#!/usr/bin/env python3
"""Matched-image short-list latency curves for legacy/core/engine modes."""
import argparse,concurrent.futures,contextlib,hashlib,io,json,subprocess
from pathlib import Path
import mpy_build as b
from runtime_profile import micro_source

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path,default=b.ROOT/'build/shortlist-micro')
    ap.add_argument('--lengths',default='0,1,2,4,6,8,9,15,16,17,32,64')
    ap.add_argument('--loops',type=int,default=8)
    ap.add_argument('--workers',type=int,default=3)
    ap.add_argument('--sim',type=Path,default=b.SIM)
    args=ap.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    fw=out/'bench_fw.py';fm=out/'bench_fw.mpy'
    fw.write_text(b.firmware_source()+'\ndef bench_ticks():\n    return _ticks()\n')
    b.mpy_cross(fw,fm,'_fw.py');b.build_firmware=lambda:fm;b.frozen_runtime_specs(compiler=False)
    cases=[]
    for n in map(int,args.lengths.split(',')):
        for kind in ['control','list_copy','reverse_slice','slice_assign','pop_insert']:
            for mixed in ([False,True] if n in [6,16] and kind!='control' else [False]):
                name=f'{kind}_{n}_{"mixed" if mixed else "int"}'
                work=out/name;work.mkdir(exist_ok=True)
                text=micro_source(kind,n,mixed,args.loops)
                ref=io.StringIO()
                with contextlib.redirect_stdout(ref):exec(compile(text,name,'exec'),{'bench_ticks':lambda:0})
                expected=next(x for x in ref.getvalue().splitlines() if x.startswith('RESULT '))
                src=work/(name+'.py');src.write_text(text)
                image=b.build_program(src,work,source_name=src.name)
                cases.append((name,image,expected))
    data={'commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'simulator_sha256':hashlib.sha256(args.sim.read_bytes()).hexdigest(),
          'firmware_sha256':hashlib.sha256(fm.read_bytes()).hexdigest(),
          'loops':args.loops,'boundary':'work() with loop/call overhead; no control subtraction',
          'validation':'common-subset CPython result and all three matched-image modes','rows':[]}
    def one(case):
        name,image,expected=case;row={'name':name,'expected':expected,'runs':[]}
        for mode in [0,1,2]:
            r=b.run_image(image,sim_executable=args.sim.resolve(),max_cycles=100_000_000,timeout=2400,
                          sim_args=['+CA=1','+AALU=1',f'+SL={mode}'])
            (image.parent/f'mode{mode}.log').write_text(r.log)
            (image.parent/f'mode{mode}.stdout').write_bytes(r.stdout)
            lines=r.stdout.decode().splitlines()
            ok=r.exit_code==0 and not r.stderr and [x for x in lines if x.startswith('RESULT ')]==[expected]
            cycles=next((int(x.split()[1]) for x in lines if x.startswith('CYCLES ')),None)
            row['runs'].append(dict(mode=mode,cycles=cycles,ok=ok,gc=r.gc,halt=r.halt))
        return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for future in concurrent.futures.as_completed([pool.submit(one,c) for c in cases]):
            row=future.result();data['rows'].append(row);data['rows'].sort(key=lambda r:r['name'])
            (out/'results.json').write_text(json.dumps(data,indent=2)+'\n')
            print(row['name'],[(r['mode'],r['cycles'],r['ok']) for r in row['runs']],flush=True)
    return int(any(not r['ok'] for row in data['rows'] for r in row['runs']))
if __name__=='__main__':raise SystemExit(main())
