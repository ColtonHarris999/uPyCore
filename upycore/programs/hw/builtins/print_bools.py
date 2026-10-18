# Ported from pycore pycore/programs/img_print_bools.py.
"""BOOL True/False literals."""


def managed_entry():
    print(False, True, sep="/")
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
