# Ported from pycore pycore/programs/img_print_many.py.
"""More than two positionals (proves not limited by trap mailbox arity)."""


def managed_entry():
    print(1, 2, 3, 4, 5)
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
