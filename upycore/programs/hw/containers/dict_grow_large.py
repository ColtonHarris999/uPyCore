# Ported from pycore pycore/programs/img_dict_grow_large.py.
"""Insert ~20 INT keys forcing multiple DICT_GROW traps; return sum.

Uses while (no FOR_ITER). Requires EXCORE_EN=1.
"""


def managed_entry():
    d = {}
    i = 0
    while i < 20:
        d[i] = i + 1
        i = i + 1
    s = 0
    i = 0
    while i < 20:
        s = s + d[i]
        i = i + 1
    return s

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
