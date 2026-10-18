import gc

# Ported from pycore pycore/programs/img_gc_bench_wide.py.
"""G13 benchmark: one very wide list of small objects (gc_plan.md G13: mark-stack breadth).

8,000 elements: the list buffer (256 KB) plus 8,000 one-element tuples fill
most of the dynamic heap. (The plan's 16k elements would need ~1 MB.)
"""


def managed_entry():
    n = 120
    wide = [0] * n
    for i in range(n):
        wide[i] = (i,)
    gc.collect()
    gc.collect()
    total = 0
    for i in range(0, n, 97):
        total = total + wide[i][0]
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
