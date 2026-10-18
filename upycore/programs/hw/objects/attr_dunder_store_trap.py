# Ported from pycore pycore/programs/img_attr_dunder_store_trap.py.
"""STORE_ATTR on __dict__ → PY_TRAP_TYPE (1).

"""


def managed_entry():
    o.__dict__ = 1
    return 0


class _o:
    pass
o = _o()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
