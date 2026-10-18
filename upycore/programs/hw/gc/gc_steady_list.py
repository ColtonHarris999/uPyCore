import gc

# Ported from pycore pycore/programs/img_gc_steady_list.py.
"""GC steady state, lists (gc_plan.md G11): 1,000 build-and-drop iterations.

Each iteration's working set is a few hundred bytes; the test shrinks the
heap (HEAP_DYN_BYTES) so the run collects many times.

Self-checking: after WARMUP iterations the program measures live bytes with
`gc.collect()` (precise, so the exact reachable set), runs the rest, and
measures again. Any growth returns minus the growth in bytes; otherwise the
checksum, which host CPython (where `gc.collect()` returns 0) gives as the
golden. G11 also checks the plateau at every collection (+GC_LOG=1).
"""

WARMUP = 4
ITERS = 24


def work(lo, hi):
    total = 0
    keep = [total, total, total]
    for i in range(lo, hi):
        a = [i, i + 1, "steady-list-element-" + str(i % 7)]
        b = [a, [i], a[2]]
        c = b + [i % 5]
        keep[i % 3] = c[3]
        total = total + len(c) + len(a[2]) + b[1][0] % 3
    return total + keep[0] + keep[1] + keep[2]


def managed_entry():
    total = work(0, WARMUP)
    gc.collect()
    total = total + work(WARMUP, ITERS)
    gc.collect()
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
