# Ported from pycore pycore/programs/img_attr_type_trap.py.
"""LOAD_ATTR on a non-OBJECT receiver → PY_TRAP_TYPE (1)."""


def managed_entry():
    x = 1
    return x.foo

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
