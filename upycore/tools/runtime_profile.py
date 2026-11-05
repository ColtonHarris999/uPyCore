#!/usr/bin/env python3
"""Phase-0 matched-image benchmarks and passive RTL cycle attribution.

Examples (from repository root):
  python upycore/tools/runtime_profile.py --out build/phase0
  python upycore/tools/runtime_profile.py --micro --out build/phase0-micro
  python upycore/tools/runtime_profile.py --before /path/to/plain-sim --out build/phase0
The same linked image is used by both executables. --before is an uninstrumented
simulator; profile and reference kernel cycles and results must match exactly.
"""
from __future__ import annotations
import argparse, concurrent.futures, contextlib, io, hashlib, fcntl, json, os, re, subprocess, sys
from pathlib import Path
import mpy_build as b

GROUPS=['user','firmware_other','bytearray_load','bytearray_store','slice_normalize',
        'slice_get','slice_assign','list_pop','list_insert','allocation_helper',
        'list_materialize','frame_transition','subscr_other','setsubscr_other']
REASONS=['execute','allocator_wait','gc_service','scoreboard_wait','memory_grant_wait',
         'memory_response_wait','fetch_empty','native_service','call_frame_service','aalu_service','reserved10','reserved11']
SPECIFIC={'_slice_range':4,'_slice_len':4,'_clamp':4,'_getslice':5,'_list_setslice':6,
          'list__pop':7,'list__insert':8,'_newlist':9,'_list_reserve':9,'_alloc':9,
          '_list_of_seq':10,'_list_of_iter':10,'_subscr':12,'_setsubscr':13}
LENGTHS=[0,1,2,4,6,8,16,32,64,256,1024]

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=b.ROOT,text=True).strip()
def state_names():
    text=(b.ROOT/'upycore/rtl/mpy_core.sv').read_text()
    body=re.search(r'typedef enum logic\s*\[[^]]+\]\s*\{(.*?)\}\s*state_e',text,re.S).group(1)
    return re.findall(r'\bS_\w+\b',body)

def build_profiler(out,jobs):
    target=out/'sim-profile';target.mkdir(parents=True,exist_ok=True)
    exe=target/'Vtb_mpy_soc'
    sources=[b.ROOT/p for p in b.RTL+b.RTL_INCLUDES]+[b.ROOT/'upycore/tb/mpy_profile.svh']
    fingerprint=hashlib.sha256((''.join(sha(p) for p in sources)+os.environ.get('VERILATOR','verilator')).encode()).hexdigest()
    stamp=target/'fingerprint'
    if not exe.exists() or not stamp.exists() or stamp.read_text()!=fingerprint:
        cmd=[os.environ.get('VERILATOR','verilator'),'-sv','--binary','--timing','--timescale','1ns/1ps','-O3',
             '--x-assign','fast','--x-initial','fast','-DMPY_PROFILE',f'+incdir+{b.ROOT / "upycore/rtl"}',
             '-y',str(b.ROOT/'upycore/rtl'),'--top-module','tb_mpy_soc','--Mdir',str(target),
             '-Wno-fatal','-Wno-WIDTH','-Wno-UNUSED','-Wno-CASEINCOMPLETE','-Wno-BLKSEQ','-Wno-TIMESCALEMOD',
             '-j',str(jobs)]+[str(p) for p in sources if p.suffix=='.sv']
        r=subprocess.run(cmd,cwd=b.ROOT,capture_output=True,text=True)
        (out/'build-profile.log').write_text(r.stdout+r.stderr)
        if r.returncode:raise RuntimeError((r.stdout+r.stderr)[-6000:])
        stamp.write_text(fingerprint)
    return exe

def kernel_source(name):
    src=b.ROOT/'vendor/micropython/tests/perf_bench'/f'{name}.py'
    # Match the original measurement's variable names/boundary exactly. These
    # two sources have no colliding globals; other suites must use unique names.
    return src.read_text()+'''
selected=(0,0)
params=None
for nm,p in bm_params.items():
    if 10*nm[0] <= 1200 and nm[1] <= 100 and nm > selected:
        selected=nm
        params=p
if params is None:
    print('SKIP no matching N=100 M=100 parameters')
else:
    run,result=bm_setup(params)
    start=bench_ticks()
    run()
    elapsed=bench_ticks()-start
    print('CYCLES',elapsed)
    print('RESULT',result())
'''

def micro_source(kind,n,mixed,loops):
    items="[palette[i % 7] for i in range(n)]" if mixed else 'list(range(n))'
    setup=f'n={n}\npalette=[0,None,1.25,True,"x",(),[]]\na={items}\nb=a[:]\nbuf=bytearray(n)\n'
    if kind=='byte_read':
        setup+='buf=bytearray(bytes([(i*17+3)&255 for i in range(n)]))\n'
        stmt='for i in range(n):\n            x=buf[i]'
    elif kind=='byte_write':stmt='for i in range(n):\n            buf[i]=i & 255'
    elif kind=='list_copy':stmt='x=a[:]'
    elif kind=='reverse_slice':stmt='x=a[::-1]'
    elif kind=='slice_assign':stmt='a[:]=b'
    elif kind=='pop_insert':stmt='if n:\n            x=a.pop(0)\n            a.insert(n-1,x)'
    else:stmt='pass'
    # Operand/result construction happens outside the timed callable. Controls
    # capture Python loop costs; do not silently subtract them from raw cycles.
    return setup+f'''\ndef work():
    x=0
    for repeat in range({loops}):
        {stmt}
    return (len(a),x)
start=bench_ticks()
x=work()
elapsed=bench_ticks()-start
print('CYCLES',elapsed)
print('RESULT', (x, a, list(buf)))
'''

def lut_for(image,work):
    m=json.loads(Path(str(image)+'.map.json').read_text())
    functions={'0':'<frame-transition-or-unknown>'};lut=[0]*131072
    for i,(addr,name) in enumerate(m['rc'].items(),1):
        if i>=2048:raise ValueError('profiler function capacity')
        functions[str(i)]=name
        group=SPECIFIC.get(name.split(':',1)[-1],0) if name.startswith('_fw:') else 0
        lut[int(addr,16)//4]=i+(group<<16)+(int(name.startswith('_fw:'))<<24)
    path=work/'profile.lut.hex';path.write_text(''.join(f'{v:08x}\n' for v in lut))
    states=state_names(); flags=[]
    for name in states:
        v=int(name.startswith('S_FL') or name in ['S_FILL','S_RET_D'])
        v|=2*int(name.startswith('S_GC'))
        v|=4*int(name.startswith(('S_NAT','S_N_')))
        v|=8*int(name.startswith(('S_CF','S_BF','S_BS','S_SP')))
        v|=16*int(name.startswith('S_AALU'))
        flags.append(v)
    flags+=[0]*(2048-len(flags))
    (work/'states.hex').write_text(''.join(f'{v:08x}\n' for v in flags))
    return path,functions

def parse_profile(path,functions,states):
    out={'functions':{},'groups':{},'reasons':{},'group_reasons':{},'states':{},'events':{},'opcode_pc_counts':{}}
    for line in path.read_text().splitlines():
        parts=line.split();kind=parts[0];v=parts[1:]
        if kind=='META':out['start'],out['stop'],out['cycles'],out['tick_reads'],out['ancestry_warnings']=map(int,v)
        elif kind=='FUNCTION':
            i,self_,incl,entries=map(int,v);out['functions'][functions[str(i)]]={'self_cycles':self_,'inclusive_cycles':incl,'entries':entries}
        elif kind=='GROUP':out['groups'][GROUPS[int(v[0])] if int(v[0])<len(GROUPS) else v[0]]=int(v[1])
        elif kind=='REASON':out['reasons'][REASONS[int(v[0])]]=int(v[1])
        elif kind=='CROSS':out['group_reasons'][f'{GROUPS[int(v[0])]} / {REASONS[int(v[1])]}']=int(v[2])
        elif kind=='STATE':out['states'][states[int(v[0])]]=int(v[1])
        elif kind=='EVENT':out['events'][v[0]]=int(v[1])
        elif kind=='PC':out['opcode_pc_counts'][hex(int(v[0]))]=int(v[1])
    if out.get('tick_reads')!=2:raise ValueError('kernel must read _ticks exactly twice')
    if out.get('stop',0)-out.get('start',0)!=out.get('cycles'):raise ValueError('profile interval mismatch')
    if out.get('ancestry_warnings'):raise ValueError('incomplete/cyclic callable ancestry; refuse inclusive totals')
    for key in ['groups','reasons','states','group_reasons']:
        if sum(out[key].values())!=out['cycles']:raise ValueError(f'{key} does not partition cycles')
    if sum(r['self_cycles'] for r in out['functions'].values())!=out['cycles']:raise ValueError('self cycle mismatch')
    return out

def run_one(case,out,profiler,before,max_cycles,timeout,flags):
    name,source,expected,source_hash=case;work=out/name;work.mkdir(parents=True,exist_ok=True)
    src=work/(name+'.py');src.write_text(source)
    image=b.build_program(src,work,source_name=name+'.py')
    lut,functions=lut_for(image,work)
    row={'name':name,'source_sha256':source_hash,'harness_sha256':sha(src),'expected_result':expected,
         'image_sha256':{s:sha(str(image)+s) for s in ['.hex','.tags.hex']},'flags':flags}
    def run(exe,label,extra):
        r=b.run_image(image,max_cycles=max_cycles,timeout=timeout,sim_executable=exe,sim_args=flags+extra)
        (work/f'{label}.log').write_text(r.log)
        (work/f'{label}.stdout').write_bytes(r.stdout);(work/f'{label}.stderr').write_bytes(r.stderr)
        if r.exit_code:raise RuntimeError(f'{name} {label}: {r.halt}: {r.stderr!r}')
        lines=r.stdout.decode().splitlines();times=[x for x in lines if x.startswith('CYCLES ')]
        checks=[x for x in lines if x.startswith('RESULT ')]
        if len(times)!=1 or checks!=[expected]:raise RuntimeError(f'{name} bad result: {lines}')
        return {'cycles':int(times[0].split()[1]),'total_cycles':r.cycles,'ops':r.ops,'gc':r.gc,'result':checks[0]}
    # Sequential runs share precisely the same linked image and output prefix.
    if before:row['reference']=run(before,'reference',[])
    row['profiled']=run(profiler,'profiled',[f'+PROFILE={work / "profile.raw"}',f'+PROFILE_LUT={lut}',f'+PROFILE_STATES={work / "states.hex"}'])
    row['profile']=parse_profile(work/'profile.raw',functions,state_names())
    if row['profile']['cycles']!=row['profiled']['cycles']:raise ValueError(f'{name}: timer/profile boundary mismatch')
    if before and row['reference']['cycles']!=row['profiled']['cycles']:raise ValueError(f'{name}: instrumentation changed cycles')
    row['time_ms_18ns']=row['profiled']['cycles']*.000018
    (work/'result.json').write_text(json.dumps(row,indent=2)+'\n')
    print(name,row['profiled']['cycles'],flush=True)
    return row

def metadata(profiler,before):
    return {'commit':git('rev-parse','HEAD'),'working_tree_diff_sha256':hashlib.sha256(git('diff','--','upycore').encode()).hexdigest(),
            'micropython':git('-C','vendor/micropython','rev-parse','HEAD'),'compiler_sha256':sha(b.MPY_CROSS),
            'compiler_flags':b.MPY_CROSS_FLAGS,'firmware_sources':{p.name:sha(p) for p in b.FW_SRC.glob('*.py')},
            'rtl_sources':{p:sha(b.ROOT/p) for p in b.RTL+b.RTL_INCLUDES},
            'profiler_sha256':sha(profiler),'reference_sha256':sha(before) if before else None,
            'verilator':subprocess.check_output([os.environ.get('VERILATOR','verilator'),'--version'],text=True).strip(),
            'clock_period_ns':18,'boundary':'first two native _ticks samples; [start, stop)',
            'semantics':'Groups and reasons partition cycles; function inclusive counts overlap and exclude frame restoration. Ancestry warnings must be inspected.',
            'rows':[]}

def run_project_suite(args,out,profiler):
    import bench
    fw=b.build_firmware();b.frozen_runtime_specs(compiler=False)
    data=metadata(profiler,args.before.resolve() if args.before else None)
    data['suite']='original project programs, production firmware, four modes'
    data['firmware_sha256']=sha(fw)
    def one(src):
        work=out/src.stem;work.mkdir(parents=True,exist_ok=True)
        image=b.build_program(src,work,source_name=src.name)
        row={'name':src.stem,'source_sha256':sha(src),'image_sha256':{x:sha(str(image)+x) for x in ['.hex','.tags.hex']},'runs':[]}
        expected=None
        for mode,flags in bench.CONFIGS:
            values={}
            for label,exe in [('reference',args.before),('profile_disabled',profiler)]:
                if exe is None:continue
                r=b.run_image(image,max_cycles=args.max_cycles,timeout=args.timeout,sim_executable=exe.resolve(),sim_args=flags)
                (work/f'{mode}-{label}.log').write_text(r.log)
                (work/f'{mode}-{label}.stdout').write_bytes(r.stdout)
                (work/f'{mode}-{label}.stderr').write_bytes(r.stderr)
                if r.exit_code:raise RuntimeError(f'{src.stem} {mode} {label}: {r.halt}')
                outputs=(r.stdout,r.stderr)
                if expected is not None and outputs!=expected:raise ValueError(f'{src.stem}: output mismatch')
                expected=outputs
                values[label]={'cycles':r.cycles,'ops':r.ops,'gc':r.gc,'stdout_sha256':hashlib.sha256(r.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(r.stderr).hexdigest()}
            if args.before and values['reference']!=values['profile_disabled']:raise ValueError(f'{src.stem}: passive build mismatch')
            row['runs'].append({'mode':mode,**values})
        print('project',src.stem,'pass',flush=True);return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for row in pool.map(one,sorted((b.ROOT/'upycore/programs/bench').glob('*.py'))):
            data['rows'].append(row);(out/'results.json').write_text(json.dumps(data,indent=2)+'\n')

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',type=Path,default=b.ROOT/'build/runtime-profile')
    ap.add_argument('--project-suite',action='store_true');ap.add_argument('--before',type=Path);ap.add_argument('--micro',action='store_true');ap.add_argument('--loops',type=int,default=8)
    ap.add_argument('--lengths',default=','.join(map(str,LENGTHS)));ap.add_argument('--cases',default='misc_aes,bm_fannkuch')
    ap.add_argument('--workers',type=int,default=2);ap.add_argument('--jobs',type=int,default=2);ap.add_argument('--max-cycles',type=int,default=400_000_000)
    ap.add_argument('--timeout',type=int,default=1800);ap.add_argument('--ca',type=int,choices=[0,1],default=1)
    ap.add_argument('--aalu',type=int,choices=[0,1],default=1);args=ap.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    lock_fd=os.open(out/'.runtime_profile.lock',os.O_CREAT|os.O_RDWR,0o600)
    try:fcntl.flock(lock_fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:raise RuntimeError(f'another profiler owns {out}')
    profiler=build_profiler(out,args.jobs)
    if args.project_suite:
        run_project_suite(args,out,profiler);return
    fwsrc=out/'bench_fw.py';fwmpy=out/'bench_fw.mpy'
    fwsrc.write_text(b.firmware_source()+'\ndef bench_ticks():\n    return _ticks()\n');b.mpy_cross(fwsrc,fwmpy,'_fw.py');b.build_firmware=lambda:fwmpy
    cases=[]
    if args.micro:
        for n in map(int,args.lengths.split(',')):
            for kind in ['control','byte_read','byte_write','list_copy','reverse_slice','slice_assign','pop_insert']:
                for mixed in ([False,True] if kind not in ['control','byte_read','byte_write'] else [False]):
                    name=f'{kind}_{n}_{"mixed" if mixed else "int"}'
                    source=micro_source(kind,n,mixed,args.loops)
                    ref=io.StringIO()
                    with contextlib.redirect_stdout(ref):exec(compile(source,name,'exec'),{'bench_ticks':lambda:0})
                    expected=next(line for line in ref.getvalue().splitlines() if line.startswith('RESULT '))
                    cases.append((name,source,expected,None))
    else:
        for name in args.cases.split(','):
            if name not in ['misc_aes','bm_fannkuch']:raise ValueError('Only collision-checked AES/Fannkuch sources supported')
            p=b.ROOT/'vendor/micropython/tests/perf_bench'/f'{name}.py'
            ns={};exec(compile(p.read_text(),str(p),'exec'),ns)
            nm=max(nm for nm in ns['bm_params'] if 10*nm[0]<=1200 and nm[1]<=100)
            run,result=ns['bm_setup'](ns['bm_params'][nm]);run();expected='RESULT '+str(result())
            cases.append((name,kernel_source(name),expected,sha(p)))
    before=args.before.resolve() if args.before else None
    data=metadata(profiler,before);data['measurement_firmware_sha256']=sha(fwmpy);data['micro_loops']=args.loops if args.micro else None
    # Warm the shared frozen-module cache before concurrent independent images.
    b.frozen_runtime_specs(compiler=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures=[pool.submit(run_one,case,out,profiler,before,args.max_cycles,args.timeout,[f'+CA={args.ca}',f'+AALU={args.aalu}']) for case in cases]
        for future in concurrent.futures.as_completed(futures):
            try:row=future.result()
            except Exception:
                for pending in futures:pending.cancel()
                raise
            data['rows'].append(row)
            data['rows'].sort(key=lambda r:r['name'])
            (out/'results.json').write_text(json.dumps(data,indent=2)+'\n')

if __name__=='__main__':main()
