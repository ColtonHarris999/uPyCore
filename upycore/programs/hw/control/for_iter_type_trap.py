# Ported from pycore pycore/programs/img_for_iter_type_trap.py.
"""GET_ITER on an unsupported scalar must raise PY_TRAP_TYPE (1)."""


def managed_entry():
    total = 0
    for value in 7:
        total += value
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
