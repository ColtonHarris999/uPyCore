# Ported from pycore pycore/programs/img_for_iter_object_no_iter_trap.py.
"""Object without __iter__ → PY_TRAP_TYPE on GET_ITER.

"""


def managed_entry():
    total = 0
    for x in o:
        total += x
    return total


class T:
    pass
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
