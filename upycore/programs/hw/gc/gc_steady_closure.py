import gc

# Ported from pycore pycore/programs/img_gc_steady_closure.py.
def make(k):
    def add(x):
        return x + k
    return add

"""GC steady state, closures (gc_plan.md G11): 1,000 closures with cells, called and dropped.

The factory comes from the on-device compiler (closures are not in the image
path); each iteration creates a cell and a FUNCTION object.

Self-checking: after WARMUP iterations the program measures live bytes with
`gc.collect()` (precise, so the exact reachable set), runs the rest, and
measures again. Any growth returns minus the growth in bytes; otherwise the
checksum, which host CPython (where `gc.collect()` returns 0) gives as the
golden. G11 also checks the plateau at every collection (+GC_LOG=1).
"""


WARMUP = 4
ITERS = 24


def work(make, lo, hi):
    total = 0
    for i in range(lo, hi):
        f = make(i % 10)
        total = total + f(i) % 13
        if i % 80 == 0:
            gc.collect()
    return total


def managed_entry():
    ns = None
    total = work(make, 0, WARMUP)
    gc.collect()
    total = total + work(make, WARMUP, ITERS)
    gc.collect()
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
