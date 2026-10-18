# Ported from pycore pycore/programs/img_print_type_trap.py.
"""Unsupported tag to _bi_print / print → TYPE trap.

Passing a list forces native BI_PRINT TYPE fatal (LONG_STR deferred;
containers unsupported).
"""


def managed_entry():
    print([1])
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
