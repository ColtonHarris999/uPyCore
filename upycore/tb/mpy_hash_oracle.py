#!/usr/bin/env python3
"""Generate RTL vectors using the pin's low-quality mp_float_hash C body.

No CPython hash() oracle: its numeric/string algorithms differ. The C cast
runs at runtime on x86, matching the oracle's i686 invalid-conversion result.
Other vectors model REPR_A wrapping and qstr.c's DJB2 with a 16-bit hash.
Also emits micropython_check.py to independently check the numeric/byte
vectors with the complete pinned 32-bit MicroPython interpreter.
"""
import random
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sx(x):
    x &= 0x7fffffff
    return x | 0x80000000 if x & 0x40000000 else x


def main(work):
    work.mkdir(parents=True, exist_ok=True)
    text = (ROOT / 'vendor/micropython/py/obj.h').read_text()
    body = text.split('static inline mp_int_t mp_float_hash(mp_float_t val) {', 1)[1].split('}', 1)[0]
    c = '''#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef int32_t mp_int_t;
typedef float mp_float_t;
static mp_int_t hash(mp_float_t val) {''' + body + '''}
int main(void) { uint32_t b; while (scanf("%x", &b) == 1) {
float f; memcpy(&f, &b, 4); printf("%08x\\n", (uint32_t)hash(f)); } }
'''
    (work / 'oracle.c').write_text(c)
    subprocess.run(['cc', '-O0', '-fno-fast-math', str(work / 'oracle.c'), '-o', str(work / 'oracle')], check=True)
    rng = random.Random(0xabc123)
    bits = [0, 0x80000000, 0x7f800000, 0xff800000, 0x7fc00000, 0xffffffff]
    bits += [(s << 31) | (e << 23) | f for s in range(2) for e in range(256)
             for f in (0, 1, 0x3fffff, 0x7fffff)]
    bits += [rng.getrandbits(32) for _ in range(2000)]
    out = subprocess.run([str(work / 'oracle')], input=''.join(f'{b:x}\n' for b in bits), text=True,
                         capture_output=True, check=True)
    floats = {b: sx(int(h, 16)) for b, h in zip(bits, out.stdout.splitlines())}
    vectors, mem = [], {}
    addr = 0x1000

    def alloc(words):
        nonlocal addr
        a = addr
        for i, v in enumerate(words):
            if isinstance(v, tuple): t, p = v
            else: t, p = 0, v
            mem[(a >> 2) + i] = (t << 32) | (p & 0xffffffff)
        addr += 4 * len(words)
        return a

    def vector(t, p, h=0, error=0):
        vectors.append((t, p, h, error))

    for p, h in [(1, 6), (4, 0), (5, 1)]: vector(0, p, h)
    for p in [0, 2, 3, 6, 17]: vector(0, p, error=1)
    for t in [5, 7, 15]: vector(t, 0, error=1)
    for p in [0, 1, 0xffffffff, 0x80000000, 0x7fffffff, 0x40000000] + [rng.getrandbits(32) for _ in range(300)]:
        vector(1, p, sx(p))
        vector(2, alloc([p, rng.getrandbits(32)]), sx(p))
    for b, h in floats.items(): vector(3, b, h)
    for _ in range(300):
        re, im = rng.sample(bits, 2)
        vector(4, alloc([re, im]), floats[re] ^ floats[im])
    for t in [11, 12, 14]:
        for p in [0, 0x20000100, 0xf0000000]: vector(t, p, sx(p >> 1))
    mem[0x100 >> 2] = 5381; mem[0x108 >> 2] = 4444; mem[0x200 >> 2] = 1234
    for i, h in enumerate([5381, 4444, 1234]): vector(6, i, h)
    datasets = [bytes(rng.randrange(256) for _ in range(n))
                for n in [0, 1, 2, 3, 4, 5, 15, 16, 31, 64, 127]]
    datasets.append(bytes([16, 200, 61]))  # DJB2 low 16 bits == 0, remapped to 1
    for data in datasets:
        n = len(data)
        h = 5381
        for b in data: h = ((h * 33) ^ b) & 0xffffffff
        h = h & 65535 or 1
        for offset in range(4):
            raw = b'\xee' * offset + data + b'\xff' * 4
            ptr = alloc([int.from_bytes(raw[i:i+4], 'little') for i in range(0, len(raw), 4)]) + offset
            for t in [8, 13]:
                for cached in [0, h | 0x40000000]:
                    vector(t, alloc([n, cached, ptr]), h)
    empty = alloc([0]); vector(9, empty, 12345)
    nested = alloc([3, (1, -1), (3, 0x3fc00000), (9, empty)])
    vector(9, nested, 24690)
    for i in range(8):
        nested = alloc([1, (9, nested)])
        vector(9, nested, sx(24690 + (i + 1) * 12345) if i < 6 else 0, int(i >= 6))
    vector(9, alloc([1, (10, 0)]), error=1)
    slots = alloc([(0, 0), (1, -1), (0, 3), (3, 0x40200000)])
    vector(10, alloc([2, 4, slots, 2]) | 2, 54322)
    vector(10, alloc([0, 0, 0, 2]) | 2, 54321)
    vector(10, alloc([0, 0, 0, 0]) | 2, error=1)
    assert addr < 0x40000
    (work / 'vectors.txt').write_text(''.join(f'{t:x} {p & 0xffffffff:08x} {h:08x} {e:x}\n' for t,p,h,e in vectors))
    (work / 'memory.hex').write_text(''.join(f'@{a:x} {v:09x}\n' for a,v in sorted(mem.items())))
    checks = [
        'import struct',
        'def f(b): return struct.unpack("<f", struct.pack("<I", b))[0]',
        'def check(v, h):\n    assert hash(v) == h, (v, hash(v), h)',
    ]
    for t, p, h, error in vectors:
        if error:
            continue
        value = None
        if t == 1:
            value = str(sx(p) if sx(p) < 0x80000000 else sx(p) - 0x100000000)
        elif t == 2:
            v = (mem[p >> 2] & 0xffffffff) | ((mem[(p >> 2)+1] & 0xffffffff) << 32)
            if v >= 1 << 63: v -= 1 << 64
            value = '(-9223372036854775807-1)' if v == -(1 << 63) else str(v)
        elif t == 3:
            value = f'f({p})'
        elif t == 4:
            value = f'complex(f({mem[p >> 2]}), f({mem[(p >> 2)+1]}))'
        elif t in (8, 13):
            n = mem[p >> 2]
            a = mem[(p >> 2)+2]
            data = bytes((mem[(a+i) >> 2] >> (8*((a+i)&3))) & 255 for i in range(n))
            value = repr(data)  # str and bytes use the identical byte hash
        if value is not None:
            signed = h if h < 0x80000000 else h - 0x100000000
            checks.append(f'check({value}, {signed})')
    checks.append('print("MicroPython hash vectors ok")')
    (work / 'micropython_check.py').write_text('\n'.join(checks) + '\n')
    print(f'hash oracle: {len(vectors)} vectors, {len(floats)} binary32 patterns')


if __name__ == '__main__': main(Path(sys.argv[1]))
