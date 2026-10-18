# Ported from pycore pycore/programs/img_print_neg.py.
"""Signed INT formatting through BI_PRINT."""


def managed_entry():
    print(0)
    print(-42)
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
