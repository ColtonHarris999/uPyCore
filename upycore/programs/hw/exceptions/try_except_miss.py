# Ported from pycore pycore/programs/img_try_except_miss.py.
"""except ValueError: does not catch raise TypeError → PY_TRAP_RAISE (17)."""


def managed_entry():
    try:
        raise TypeError
    except ValueError:
        return 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
