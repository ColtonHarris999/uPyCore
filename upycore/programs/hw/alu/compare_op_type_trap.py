# Ported from pycore pycore/programs/img_compare_op_type_trap.py.
"""Unsupported rich-comparison tags must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    value = None
    return value < 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
