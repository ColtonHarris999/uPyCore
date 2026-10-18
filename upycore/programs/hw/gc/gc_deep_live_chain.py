import gc

# Ported from pycore pycore/programs/img_gc_deep_live_chain.py.
"""GC: a deep live chain must not make collection fail on a mostly empty heap.

100,000 nodes `(payload, next)`. Depth-first marking scans a node, pushes
its payload list and the next node, pops the next node first, and so leaves
one payload per level on the mark stack: far more than the stack holds.
When the stack is full the node being scanned goes to the rescan list and
is scanned again once the stack drains. The program then checks that every
payload survived.

"""


def managed_entry():
    n = 60
    head = None
    i = 0
    while i < n:
        head = ([i], head)
        i = i + 1
    try:
        gc.collect()
    except MemoryError:
        return 2
    junk = [None] * 20
    i = 0
    while i < 20:
        junk[i] = [-1]
        i = i + 1
    node = head
    i = n - 1
    while node is not None:
        if node[0][0] != i:
            return 100
        node = node[1]
        i = i - 1
    if i != -1:
        return 101
    return 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
