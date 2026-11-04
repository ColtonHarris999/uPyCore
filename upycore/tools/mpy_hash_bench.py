#!/usr/bin/env python3
"""Measure hash/modulo overlap and synthesize generic PPA proxies.

VERILATOR selects the simulator. --synth uses YOSYS (yosys-slang required;
yowasp-yosys with built-in slang works too), measuring unmapped bit cells
and logic depth, not physical area, frequency or power.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'upycore/tools'))
import unit_tests as unit


def run(cmd, **kw):
    p = subprocess.run(cmd, text=True, capture_output=True, cwd=ROOT, **kw)
    if p.returncode:
        raise RuntimeError((p.stdout + p.stderr)[-4000:])
    return p.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--synth', action='store_true')
    ap.add_argument('--work', type=Path, default=ROOT / 'build/hash_bench')
    args = ap.parse_args()
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    run([sys.executable, str(unit.TB / 'mpy_hash_oracle.py'), str(work)])
    lines = [s for s in (work / 'vectors.txt').read_text().splitlines() if s.split()[3] == '0']
    memory = {}
    for s in (work / 'memory.hex').read_text().splitlines():
        a, v = s.split()
        memory[int(a[1:], 16) * 4] = int(v, 16) & 0xffffffff
    strings = [s for s in lines if s.split()[0] in ('8', 'd')]
    groups = {
        'int': [s for s in lines if s.split()[0] == '1'],
        'float': [s for s in lines if s.split()[0] == '3'],
        'int64': [s for s in lines if s.split()[0] == '2'],
        'qstr': [s for s in lines if s.split()[0] == '6'],
        'complex': [s for s in lines if s.split()[0] == '4'],
        'str_cached': [s for s in strings if memory[int(s.split()[1],16)+4] & 65535],
        'str_cold': [s for s in strings if not memory[int(s.split()[1],16)+4] & 65535],
        'mixed': lines,
    }
    measurements = []
    rtl = [str(unit.RTL / x) for x in ('mpy_hash.sv', 'upycore_umod_seq.sv', 'mpy_hash_slot.sv')]
    for bpc, width, serial in [(1,1,0), (2,1,0), (4,1,0), (4,4,0), (4,1,1), (4,4,1)]:
        obj = work / f'obj_{bpc}_{width}_{serial}'
        run([os.environ.get('VERILATOR','verilator'), *unit.FLAGS, f'-I{unit.RTL}',
             '--Mdir', str(obj), *rtl, str(unit.TB / 'tb_mpy_hash_slot.sv'),
             '--top-module', 'tb_mpy_hash_slot', f'-GBPC={bpc}',
             f'-GBYTES_PER_CYCLE={width}', f'-GSERIAL={serial}', '-GBENCHMARK=1'])
        for group, rows in groups.items():
            vf = work / f'{group}.txt'
            vf.write_text('\n'.join(rows) + '\n')
            for stall, latency in ((0,0), (0,2), (1,2)):
                p = subprocess.run([str(obj / 'Vtb_mpy_hash_slot'), f'+VECTORS={vf}', f'+STALL={stall}', f'+LATENCY={latency}'],
                                   cwd=work, text=True, capture_output=True, check=True)
                m = dict((k,int(v)) for k,v in re.findall(r'(\w+)=(\d+)',p.stdout))
                m['workload'] = group
                measurements.append(m)
                print(group, m, flush=True)
    (work / 'cycles.json').write_text(json.dumps(measurements, indent=2)+'\n')
    hash_measurements = []
    for width in (1, 4):
        obj = work / f'hash_{width}'
        run([os.environ.get('VERILATOR','verilator'), *unit.FLAGS, f'-I{unit.RTL}',
             '--Mdir', str(obj), str(unit.RTL / 'mpy_hash.sv'),
             str(unit.TB / 'tb_mpy_hash.sv'), '--top-module', 'tb_mpy_hash',
             f'-GBYTES_PER_CYCLE={width}'])
        for group in groups:
            for latency in (0, 2):
                p = subprocess.run([str(obj / 'Vtb_mpy_hash'), f'+VECTORS={work / (group + ".txt")}',
                                    '+STALL=0', f'+LATENCY={latency}'],
                                   cwd=work, text=True, capture_output=True, check=True)
                m = dict((k,int(v)) for k,v in re.findall(r'(\w+)=(\d+)',p.stdout))
                m['workload'] = group
                hash_measurements.append(m)
                print('hash', group, m, flush=True)
    (work / 'hash_cycles.json').write_text(json.dumps(hash_measurements, indent=2)+'\n')
    if args.synth:
        ppa = []
        yosys = os.environ.get('YOSYS','yosys')
        help_text = run([yosys, '-Q', '-T', '-p', 'help read_slang'])
        frontend = 'plugin -i slang; ' if 'No such command' in help_text else ''
        for top, params in [('mpy_hash', {'DEPTH':d, 'BYTES_PER_CYCLE':w}) for d in (1,4,8) for w in (1,4)] + [
            ('upycore_umod_seq', {'BPC':b}) for b in (1,2,4)] + [
            ('mpy_hash_slot', {'BPC':4, 'DEPTH':8, 'BYTES_PER_CYCLE':w}) for w in (1,4)]:
            files = rtl if top == 'mpy_hash_slot' else [str(unit.RTL / f'{top}.sv')]
            ys = frontend + f'read_slang -j 1 --single-unit -I{unit.RTL} --top {top} '
            ys += ' '.join(f'-G{k}={v}' for k,v in params.items()) + ' ' + ' '.join(files)
            ys += f'; synth -noabc -flatten -top {top}; stat; ltp -noff'
            log = run([yosys, '-Q', '-T', '-p', ys])
            name = top + '_' + '_'.join(str(v) for v in params.values())
            (work / f'{name}.log').write_text(log)
            cells = re.findall(r'(\d+) cells', log)
            # Recent Yosys uses "cells"; older versions use "Number of cells".
            if not cells: cells = re.findall(r'Number of cells:\s+(\d+)',log)
            depth = re.search(r'Longest topological path.*length=(\d+)',log)
            row = {'top':top, **params, 'cells':int(cells[-1]), 'depth':int(depth[1])}
            ppa.append(row); print(row, flush=True)
        (work / 'ppa.json').write_text(json.dumps(ppa, indent=2)+'\n')


if __name__ == '__main__': main()
