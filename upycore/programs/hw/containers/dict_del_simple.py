# Ported from pycore pycore/programs/img_dict_del_simple.py.
"""Same-tag DELETE_SUBSCR on the middle key; verify contains after.

Tombstone path on pycore (no DICT_COLLISION). Returns bitmask of checks.
"""


def managed_entry():
    d = {}
    d[1] = 10
    d[2] = 20
    d[3] = 30
    del d[2]
    n = 0
    if 1 in d:
        n = n + 1
    if 2 not in d:
        n = n + 2
    if 3 in d:
        n = n + 4
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
