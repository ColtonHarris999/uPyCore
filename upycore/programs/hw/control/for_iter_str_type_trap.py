# Ported from pycore pycore/programs/img_for_iter_str_type_trap.py.
"""GET_ITER on a non-iterable scalar raises PY_TRAP_TYPE."""


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
