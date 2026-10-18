import gc

# Ported from pycore pycore/programs/img_gc_cycle_mutual.py.
"""GC: two instances pointing at each other are reclaimed when dropped (gc_plan.md §6.4)."""


class Pair:
    def __init__(self, tag, other):
        self.tag = tag
        self.other = other


def link(n):
    a = Pair("left-node-number-" + str(n), None)
    b = Pair("right-node-number-" + str(n), a)
    a.other = b
    return a


def managed_entry():
    keep = link(1)
    garbage = link(2)
    garbage = link(3)
    garbage = None
    gc.collect()
    fresh = link(4)
    gc.collect()
    return (len(keep.tag) + len(keep.other.other.tag) + len(fresh.other.tag)) * 10 + \
        len(keep.other.other.other.tag)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
