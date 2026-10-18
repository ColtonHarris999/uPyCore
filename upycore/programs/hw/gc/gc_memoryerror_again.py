import gc

# Ported from pycore pycore/programs/img_gc_memoryerror_again.py.
"""After a caught MemoryError the next allocation that misses must collect.

The handler drops the chain without `gc.collect()`. The next list needs
a fresh run, so the allocator must collect again before it declares the heap
exhausted. B24: the failed collection's "already collected" flag survived
the MemoryError raise, so that allocation raised MemoryError with the chain
garbage still on the heap.

"""


def chain_until_full():
    try:
        drop = None
        i = 0
        while i < 100000:
            drop = (drop, i)
            i = i + 1
    except MemoryError:
        return 1
    return 1


def managed_entry():
    ok = 0
    n = 0
    while n < 3:
        ok = ok + chain_until_full()
        big = [n] * 128
        if len(big) == 128:
            n = n + 1
        big = None
    return ok

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
