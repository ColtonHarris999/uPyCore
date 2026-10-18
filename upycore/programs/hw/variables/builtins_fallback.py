# Ported from pycore pycore/programs/img_builtins_fallback.py.
"""LEGB-B: LOAD_GLOBAL resolves a name present only in the builtins dict.

`len` is seeded in the boot-record builtins dict, not in module globals.
"""


def managed_entry():
    return len((1, 2, 3, 4))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
