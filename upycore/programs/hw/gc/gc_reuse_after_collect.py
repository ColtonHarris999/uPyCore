import gc

# Ported from pycore pycore/programs/img_gc_reuse_after_collect.py.
"""GC: memory a collection frees is handed out again (gc_plan.md Phase 1).

Garbage is dropped, a collection runs, and free memory must grow; the next
allocation must then consume part of what was freed. The surviving list and
the fresh one must both read back correctly.

Free-byte counts only exist on PyCore, so the expected value is stated.
"""


def build(n):
    return [n, n + 1, n + 2, (n, n * 2), {"a": n}]


def managed_entry():
    keep = build(1)
    g1 = build(2)
    g2 = build(3)
    g3 = build(4)
    g1 = None
    g2 = None
    g3 = None
    gc.collect()
    fresh = build(5)
    gc.collect()
    return keep[0] + fresh[0] + keep[4]["a"] + fresh[3][1]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
