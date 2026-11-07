#!/usr/bin/env python3
"""Production-image project-suite capture with an explicitly selected source root."""
import argparse,concurrent.futures,hashlib,json,sys
from pathlib import Path

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    ap.add_argument('--sim',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--workers',type=int,default=3)
    args=ap.parse_args();root=args.root.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    sys.path.insert(0,str(root/'upycore/tools'))
    import mpy_build as b
    from bench import CONFIGS
    fw=b.build_firmware();b.frozen_runtime_specs(compiler=False)
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    cases=[]
    for p in sorted((root/'upycore/programs/bench').glob('*.py')):
        work=out/p.stem;work.mkdir(exist_ok=True)
        cases.append((p.stem,b.build_program(p,work,source_name=p.name),sha(p)))
    data={'source_root':str(root),'simulator_sha256':sha(args.sim),'firmware_sha256':sha(fw),'rows':[]}
    def one(case):
        name,img,source=case;row={'name':name,'source_sha256':source,'image_sha256':sha(str(img)+'.hex'),'runs':[]};expected=None
        for mode,flags in CONFIGS:
            r=b.run_image(img,sim_executable=args.sim.resolve(),sim_args=flags,max_cycles=400_000_000,timeout=3600)
            (img.parent/(mode+'.stdout')).write_bytes(r.stdout);(img.parent/(mode+'.stderr')).write_bytes(r.stderr)
            (img.parent/(mode+'.log')).write_text(r.log)
            pair=(r.stdout,r.stderr)
            if expected is None:expected=pair
            row['runs'].append(dict(mode=mode,cycles=r.cycles,gc=r.gc,stdout=r.stdout.decode(),stderr=r.stderr.decode(),ok=r.exit_code==0 and pair==expected))
        return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for f in concurrent.futures.as_completed([pool.submit(one,c) for c in cases]):
            row=f.result();data['rows'].append(row);data['rows'].sort(key=lambda r:r['name'])
            (out/'results.json').write_text(json.dumps(data,indent=2)+'\n');print(row['name'],[(r['mode'],r['cycles'],r['ok']) for r in row['runs']],flush=True)
    return int(any(not r['ok'] for row in data['rows'] for r in row['runs']))
if __name__=='__main__':raise SystemExit(main())
