import gc

# Ported from pycore pycore/programs/img_gc_memoryerror_caught.py.
"""A final GC allocation failure raises a catchable MemoryError.

"""


def managed_entry():
    gc.collect()
    try:
        values = [3] * 10000
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
