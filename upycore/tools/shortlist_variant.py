#!/usr/bin/env python3
"""Build an 8/16-element SoC variant without replacing the default simulator."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
import mpy_build as b

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--max',type=int,choices=[8,16],default=8)
    ap.add_argument('--mode',type=int,choices=[0,1,2],default=2)
    ap.add_argument('--out',type=Path,default=b.ROOT/'build/shortlist8')
    ap.add_argument('--jobs',type=int,default=3)
    a=ap.parse_args();a.out=a.out.resolve();obj=a.out/'obj';obj.mkdir(parents=True,exist_ok=True)
    cmd=[os.environ.get('VERILATOR','verilator'),'-sv','--binary','--timing','--timescale','1ns/1ps',
         '-O3','--x-assign','fast','--x-initial','fast','+incdir+'+str(b.ROOT/'upycore/rtl'),
         '-y',str(b.ROOT/'upycore/rtl'),'--top-module','tb_mpy_soc','--Mdir',str(obj),
         '-Wno-fatal','-Wno-WIDTH','-Wno-UNUSED','-Wno-CASEINCOMPLETE','-Wno-BLKSEQ',
         '-Wno-TIMESCALEMOD','-j',str(a.jobs),f'-GSHORTLIST_MAX={a.max}',f'-GSHORTLIST_MODE={a.mode}']
    cmd += [str(b.ROOT/p) for p in b.RTL]
    subprocess.run(cmd,cwd=b.ROOT,check=True)
    data={'max':a.max,'mode':a.mode,'command':cmd,'rtl_sha256':{p:hashlib.sha256((b.ROOT/p).read_bytes()).hexdigest() for p in b.RTL+b.RTL_INCLUDES},'simulator_sha256':hashlib.sha256((obj/'Vtb_mpy_soc').read_bytes()).hexdigest()}
    (a.out/'build.json').write_text(json.dumps(data,indent=2)+'\n')
if __name__=='__main__':main()
