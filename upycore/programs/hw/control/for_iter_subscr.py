# Ported from pycore pycore/programs/img_for_iter_subscr.py.
"""Loop var drives NB_SUBSCR reads inside the body.

Expected result: data[0] + data[1] + data[2] = 10 + 20 + 30 = 60.
"""


def managed_entry():
    a, b, c = 10, 20, 30
    data = [a, b, c]
    total = 0
    for i in [0, 1, 2]:
        total += data[i]
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
