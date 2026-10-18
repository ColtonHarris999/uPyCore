# Ported from pycore pycore/programs/img_list_del_oob.py.
"""DELETE_SUBSCR OOB → PY_TRAP_MEM_FAULT (trap code 7)."""


def managed_entry():
    x0 = 1
    x1 = 2
    a = [x0, x1]
    del a[5]
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
