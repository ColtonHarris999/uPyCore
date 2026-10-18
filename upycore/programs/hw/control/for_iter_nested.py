# Ported from pycore pycore/programs/img_for_iter_nested.py.
"""Nested LIST/TUPLE for-loops — two stacked iterators.

Expected result: 1*10 + 1*20 + 2*10 + 2*20 = 90.
"""


def managed_entry():
    total = 0
    for a in [1, 2]:
        for b in [10, 20]:
            total += a * b
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
