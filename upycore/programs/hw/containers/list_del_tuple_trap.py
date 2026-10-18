# Ported from pycore pycore/programs/img_list_del_tuple_trap.py.
"""DELETE_SUBSCR on a tuple → PY_TRAP_TYPE (trap code 1)."""


def managed_entry():
    t = (1, 2, 3)
    del t[0]
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
