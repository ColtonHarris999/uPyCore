# Ported from pycore pycore/programs/img_for_iter_build_tuple.py.
"""GET_ITER on a runtime BUILD_TUPLE (not a folded constant).

Expected result: 4 + 5 = 9.
"""


def managed_entry():
    p, q = 4, 5
    total = 0
    for x in (p, q):
        total += x
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
