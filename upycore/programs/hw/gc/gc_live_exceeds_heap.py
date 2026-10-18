# Ported from pycore pycore/programs/img_gc_live_exceeds_heap.py.
"""GC: genuinely live data larger than the heap is a clean OOM (gc_plan.md §6.4).

Every allocation stays reachable through the chain, so each collection frees
nothing; after the loop guard's second fruitless collection the allocation
fails with `PY_TRAP_MEM_FAULT` (v1) instead of hanging or corrupting.

"""


def managed_entry():
    chain = None
    n = 0
    try:
        while n < 100:
            chain = (chain, [n] * 128)
            n = n + 1
    except MemoryError:
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
