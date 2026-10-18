# Ported from pycore pycore/programs/img_gc_ltt_churn.py.
"""LIST_TO_TUPLE under a small heap so G9 row 9 abort/collects.

Build the source list once so BUILD_LIST does not steal the run-end abort.
Each iteration only allocates the tuple. G7 (a) gives ≈8 KB leftover after
the first collect, so a 12-element tuple (384 B) exhausts that run ~20 times
across 400 conversions.

# pycore-fold: list-to-tuple
"""


def managed_entry():
    n = 0
    lst = [n, n + 1, n + 2, n + 3, n + 4, n + 5, n + 6, n + 7, n + 8, n + 9,
           n + 10, n + 11]
    total = 0
    keep = (0,)
    for i in range(400):
        # Starred tuple display is not in this MicroPython.
        t = tuple(lst)
        keep = t
        total = total + t[i % 12] + len(t)
    return total + keep[1]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
