#!/usr/bin/env python3
"""Compare bulk, copy-only and disabled CA with identical firmware and ALU.
The copy-only column retains bulk-native admission overhead; it is a controlled
engine comparison, not a historical binary comparison. JSON stores raw cycles.
"""
import argparse
import json
import subprocess
from pathlib import Path
import mpy_build as build


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('programs', nargs='*', type=Path)
    ap.add_argument('--compiler', choices=('mpy-cross','mpyc'), default='mpy-cross')
    ap.add_argument('--historical-ref', help='also build the firmware from this exact git ref')
    ap.add_argument('--historical-sim', type=Path, help='use this prior RTL simulator with historical firmware, including bulk mode')
    ap.add_argument('--out', type=Path, default=build.ROOT / 'build/bulk_bench.json')
    args = ap.parse_args()
    if args.historical_sim and not args.historical_ref:
        ap.error('--historical-sim requires --historical-ref')
    programs = args.programs or [build.ROOT/'upycore/programs/bench'/f'{n}.py' for n in ('dict','listops','listbuild')]
    build.build_sim()
    historical_fw = None
    if args.historical_ref:
        ref = subprocess.check_output(['git','rev-parse',args.historical_ref],cwd=build.ROOT,text=True).strip()
        source = build.BUILD/'bulk_bench'/'historical_sources'
        source.mkdir(parents=True,exist_ok=True)
        for name in build.FW_ORDER:
            content = subprocess.check_output(['git','show',f'{ref}:upycore/firmware/{name}'],cwd=build.ROOT)
            (source/name).write_bytes(content)
        current_source = build.FW_SRC
        build.FW_SRC = source
        try:
            historical_fw = build.build_firmware(build.BUILD/'bulk_bench'/'historical_fw')
        finally:
            build.FW_SRC = current_source
    rows = []
    for p in programs:
        image = build.build_program(p.resolve(), build.BUILD/args.out.stem/p.stem, p.name, compiler=args.compiler)
        row = {'program':p.name, 'compiler':args.compiler}
        expected = None
        for name, flags in [('off',['+CA=0']),('copy_only',['+CA=1','+BULK=0']),('bulk',['+CA=1','+BULK=1'])]:
            r = build.run_image(image, 400_000_000, sim_args=flags+['+AALU=1'])
            if r.exit_code != 0: raise RuntimeError(f'{p}: {name}: {r.halt}\n{r.stdout}\n{r.stderr}')
            output = (r.stdout,r.stderr)
            if expected is not None and output != expected: raise RuntimeError(f'{p}: output mismatch in {name}: {output!r} != {expected!r}')
            expected = output
            row[name] = r.cycles
        if historical_fw:
            old_image = build.link(image.parent/'main.mpy',historical_fw,image.parent/'historical',build.frozen_runtime_specs(compiler=False))
            row['historical_ref'] = ref
            modes = [('historical_off',['+CA=0']),('historical_copy',['+CA=1','+BULK=0'])]
            if args.historical_sim:
                row['historical_rtl_simulator'] = str(args.historical_sim)
                modes.append(('historical_bulk',['+CA=1','+BULK=1']))
            for name,flags in modes:
                r = build.run_image(old_image,400_000_000,sim_args=flags+['+AALU=1'], sim_executable=args.historical_sim)
                if r.exit_code != 0 or (r.stdout,r.stderr) != expected:
                    raise RuntimeError(f'{p}: historical mismatch in {name}: {r.halt}')
                row[name] = r.cycles
        row['bulk_vs_copy'] = row['bulk']/row['copy_only']-1
        rows.append(row)
        print(json.dumps(row),flush=True)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(rows,indent=2)+'\n')

if __name__=='__main__':main()
