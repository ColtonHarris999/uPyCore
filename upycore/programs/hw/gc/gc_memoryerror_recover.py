import gc

# Ported from pycore pycore/programs/img_gc_memoryerror_recover.py.
"""Dropping live data after MemoryError permits allocation to resume.

"""


def managed_entry():
    chain = None
    try:
        i = 0
        while i < 100:
            chain = (chain, [i] * 128)
            i = i + 1
    except MemoryError:
        chain = None
        gc.collect()
        probe = (11, 22, 33)
        if len(probe) == 3:
            return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
