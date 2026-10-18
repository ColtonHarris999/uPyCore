import gc

# Ported from pycore pycore/programs/img_gc_boot_reset.py.
"""GC: a collection right after boot sees only static roots (gc_plan.md §6.4).

The first collection after reset clears the bitmap (no sweep ran before) and
finds no dynamic object; the second one runs from the swept state.
"""


def managed_entry():
    gc.collect()
    x = [1, "allocated-after-the-boot-collection"]
    gc.collect()
    return len(x[1]) * 10 + x[0]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
