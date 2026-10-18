# Ported from pycore pycore/programs/img_for_iter_range_type_trap.py.
"""range() rejects unsupported argument tags with PY_TRAP_TYPE (1)."""


def managed_entry():
    total = 0
    for value in range(1.5):
        total += value
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
