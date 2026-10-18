# Ported from pycore pycore/programs/img_builtin_int_type_trap.py.
"""int() of a non-convertible tag must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    return int(None)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
