# Ported from pycore pycore/programs/img_builtin_chr_range_trap.py.
"""chr() above U+10FFFF must raise PY_TRAP_TYPE (trap 1).

CPython raises ValueError; PyCore has no exception object for it.
"""


def managed_entry():
    return chr(1114112)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
