import gc

# Ported from pycore pycore/programs/img_gc_bench_deep.py.
"""G13 benchmark: a 10,000-deep linked chain (gc_plan.md G13 P7: mark-stack depth and spill)."""


def managed_entry():
    chain = None
    for i in range(200):
        chain = (chain,)
    gc.collect()
    gc.collect()
    depth = 0
    while chain is not None:
        chain = chain[0]
        depth = depth + 1
    return depth

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
