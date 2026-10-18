# Ported from pycore pycore/programs/img_builtin_str_type_trap.py.
"""str() of an unsupported tag must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    return str([])

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
