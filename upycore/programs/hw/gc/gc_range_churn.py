# Ported from pycore pycore/programs/img_gc_range_churn.py.
"""CALL range wide (G9 row 25): mode-1 96 B 3-tuple, never iterated."""


def managed_entry():
    total = 0
    keep = None
    for i in range(800):
        # 2**40 does not fit in a machine word here.
        keep = range(0, 1000003, 7)
        total = total + i
    return total + (0 if keep is None else 1)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
