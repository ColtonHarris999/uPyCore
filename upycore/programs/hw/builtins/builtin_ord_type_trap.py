# Ported from pycore pycore/programs/img_builtin_ord_type_trap.py.
"""ord() of a non-string must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    return ord(5)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
