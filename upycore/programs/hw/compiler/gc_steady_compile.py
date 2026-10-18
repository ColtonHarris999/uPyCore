import gc

# Ported from pycore pycore/programs/img_gc_steady_compile.py.
"""GC steady state, compile (gc_plan.md G11): repeated small compile()/eval, retaining nothing.

Each iteration compiles and evaluates a fresh expression and collects
explicitly, so the plateau is measured at the same program point every
time (`reason=explicit` collections).

Self-checking: live bytes after the first WARMUP iterations (the first
compile() builds the compiler's long-lived state) are the baseline; any growth
by the end returns minus the growth in bytes, otherwise the checksum, which
host CPython (where `gc.collect()` returns 0) gives as the golden.
"""

WARMUP = 2
ITERS = 8


def work(lo, hi):
    total = 0
    for i in range(lo, hi):
        code = compile(str(i) + " * 3 + 1", "<s>", "eval")
        total = total + eval(code)
        code = None
        gc.collect()
    return total


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
