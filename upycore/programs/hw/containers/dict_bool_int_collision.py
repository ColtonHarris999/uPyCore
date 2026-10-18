# Ported from pycore pycore/programs/img_dict_bool_int_collision.py.
"""INT/BOOL cross-tag STORE: d[1]=10 then d[True]=20 overwrites via rich_eq.

Rich equality runs on pycore (single-core). CPython: True == 1 → value 20.
"""


def managed_entry():
    d = {}
    d[1] = 10
    d[True] = 20
    return d[1]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
