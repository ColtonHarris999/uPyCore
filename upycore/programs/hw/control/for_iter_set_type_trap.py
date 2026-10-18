# Ported from pycore pycore/programs/img_for_iter_set_type_trap.py.
"""A non-iterable scalar still raises PY_TRAP_TYPE at GET_ITER."""


def managed_entry():
    result = 0
    for value in 7:
        result += value
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
