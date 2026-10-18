# Ported from pycore pycore/programs/img_unary_invert_float_trap.py.
"""FLOAT + UNARY_INVERT must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    z = 1.5
    return ~z

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
