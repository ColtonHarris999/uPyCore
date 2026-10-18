import gc

# Ported from pycore pycore/programs/img_gc_wide_live_list.py.
"""GC: a wide live list must not make collection fail on a mostly empty heap.

18,000 live 1-tuples in one list is about 1.2 MB of a 15 MB heap. Marking
used to push every element of the list when it scanned it, so the mark
stack (16,640 entries then) overflowed and the collection raised
MemoryError even though almost all of the heap was free. The marker now
scans a wide range in chunks and pushes the rest as one continuation entry.

"""


def managed_entry():
    n = 80
    wide = [None] * n
    i = 0
    while i < n:
        wide[i] = (i,)
        i = i + 1
    try:
        gc.collect()
    except MemoryError:
        return 2
    return 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
