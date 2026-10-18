# Ported from pycore pycore/programs/img_print_end_only.py.
"""Override end= only; sep stays default (space)."""


def managed_entry():
    print(1, 2, end="|")
    print(3)
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
