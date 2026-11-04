#!/usr/bin/env python3
"""Matched-image cycle benchmarks for two tb_mpy_soc executables.

Both designs execute identical firmware and program images. A measurement-only
firmware builtin exposes the existing _ticks native; startup and output are
outside the timed region. Loop/call/timer overhead stays inside and is identical
between designs. These are simulator cycle counts, not achieved clock rates.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpy_build as build

CASES = {
    'int_add': ('1234567', '2345678', 'a + b'),
    'int_mul': ('12345', '6789', 'a * b'),
    'int64_mul': ('1099511627793', '17', 'a * b'),
    'int_pow': ('3', '17', 'a ** b'),
    'int_to_float': ('1099511627793', '0', 'float(a)'),
    'mixed_add': ('12345', '1.25', 'a + b'),
    'float_add': ('1.25', '2.5', 'a + b'),
    'float_mul': ('1.25', '2.5', 'a * b'),
    'int_true_div': ('7', '3', 'a / b'),
}


def source(name, loops, pystone_loops):
    if name == 'pystone':
        p = build.ROOT / 'vendor/micropython/tests/perf_bench/misc_pystone.py'
        return p.read_text() + f'''
Setup()
start = bench_ticks()
Proc0({pystone_loops})
elapsed = bench_ticks() - start
print('BENCH', elapsed)
print('CHECK', IntGlob, BoolGlob, Array2Glob[8][7])
'''
    a, b, expr = CASES[name]
    return f'''
def work(n, a, b):
    x = a
    for i in range(n):
        x = {expr}
    return x

start = bench_ticks()
result = work({loops}, {a}, {b})
elapsed = bench_ticks() - start
print('BENCH', elapsed)
print('CHECK', result)
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--before', type=Path, required=True)
    ap.add_argument('--after', type=Path, required=True)
    ap.add_argument('--loops', type=int, default=1000)
    ap.add_argument('--pystone-loops', type=int, default=300)
    ap.add_argument('--out', type=Path, default=build.ROOT / 'build/timing_bench')
    args = ap.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    # Keep measurement instrumentation out of production firmware. The same
    # joined firmware (plus this thin wrapper) is linked once for both designs.
    fw_src = args.out / 'bench_fw.py'
    fw_mpy = args.out / 'bench_fw.mpy'
    fw_src.write_text(build.firmware_source() + '\ndef bench_ticks():\n    return _ticks()\n')
    build.mpy_cross(fw_src, fw_mpy, '_fw.py')
    build.build_firmware = lambda: fw_mpy
    result = {'loops':args.loops, 'pystone_loops':args.pystone_loops,
              'before':str(args.before.resolve()), 'after':str(args.after.resolve()), 'cases':[]}
    print(f"{'case':18} {'before cycles':>14} {'after cycles':>14} {'change':>10}", flush=True)
    for name in [*CASES, 'pystone']:
        work = args.out / name
        work.mkdir(exist_ok=True)
        src = work / f'{name}.py'
        src.write_text(source(name, args.loops, args.pystone_loops))
        image = build.build_program(src, work, source_name=src.name)
        row = {'name':name}
        hashes = {}
        for suffix in ['.hex','.tags.hex']:
            hashes[suffix] = hashlib.sha256(Path(str(image)+suffix).read_bytes()).hexdigest()
        row['image_sha256'] = hashes
        for design, executable in [('before',args.before),('after',args.after)]:
            sim = build.run_image(image, max_cycles=100_000_000, timeout=600,
                                  sim_executable=executable.resolve())
            if sim.exit_code != 0:
                raise RuntimeError(f'{name} {design}: {sim.halt}\n{sim.stdout!r}\n{sim.stderr!r}\n{sim.log}')
            lines = sim.stdout.decode().splitlines()
            measurements = [l for l in lines if l.startswith('BENCH ')]
            if len(measurements) != 1:
                raise RuntimeError(f'{name}: bad output {lines}')
            row[design] = {'cycles':int(measurements[0].split()[1]), 'total_cycles':sim.cycles,
                           'ops':sim.ops, 'gc':sim.gc,
                           'check':[l for l in lines if not l.startswith('BENCH ')]}
        if row['before']['check'] != row['after']['check']:
            raise RuntimeError(f'{name}: mismatched results {row}')
        row['change_pct'] = 100 * (row['after']['cycles'] / row['before']['cycles'] - 1)
        result['cases'].append(row)
        (args.out / 'results.json').write_text(json.dumps(result, indent=2)+'\n')
        print(f"{name:18} {row['before']['cycles']:14,d} {row['after']['cycles']:14,d} {row['change_pct']:+9.3f}%", flush=True)


if __name__ == '__main__':
    main()
