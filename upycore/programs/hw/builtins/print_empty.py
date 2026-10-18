# Ported from pycore pycore/programs/img_print_empty.py.
"""print() emits a lone newline."""


def managed_entry():
    print()
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
