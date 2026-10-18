# Ported from pycore pycore/programs/img_builtin_ord_len_trap.py.
"""ord() of a multi-character string must raise PY_TRAP_TYPE (trap 1).

CPython raises TypeError; PyCore has no exception object for it.
"""


def managed_entry():
    return ord("ab")

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
