# Ported from pycore pycore/programs/img_attr_del.py.
"""DELETE_ATTR then LOAD_ATTR → tombstone; second load traps ATTR_ERROR.

Trap test: expects PY_TRAP_ATTR_ERROR after delete.

"""


def managed_entry():
    del o.x
    return o.x


class _o:
    pass
o = _o()
o.x = 5

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
