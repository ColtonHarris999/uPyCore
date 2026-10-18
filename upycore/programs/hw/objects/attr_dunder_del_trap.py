# Ported from pycore pycore/programs/img_attr_dunder_del_trap.py.
"""DELETE_ATTR on __class__ → PY_TRAP_TYPE (1).

"""


def managed_entry():
    del o.__class__
    return 0


class T:
    pass
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
