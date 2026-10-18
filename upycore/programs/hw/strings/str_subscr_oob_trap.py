# Ported from pycore pycore/programs/img_str_subscr_oob_trap.py.
"""s[i] past the end must raise PY_TRAP_MEM_FAULT (trap 7), the same as lists.

CPython raises IndexError; PyCore has no exception object for it.
"""


def managed_entry():
    s = "abc"
    return s[5]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
