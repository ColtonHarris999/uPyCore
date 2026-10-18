# Ported from pycore pycore/programs/img_list_del_shift_excore.py.
"""Two-core middle DELETE_SUBSCR via PY_TRAP_LIST_DELETE (shift-down).

[10, 20, 30, 40] → del [1] → [10, 30, 40]; return 10+30+40 = 80.
"""


def managed_entry():
    x0 = 10
    x1 = 20
    x2 = 30
    x3 = 40
    a = [x0, x1, x2, x3]
    del a[1]
    return a[0] + a[1] + a[2]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
