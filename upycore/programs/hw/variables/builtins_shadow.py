# Ported from pycore pycore/programs/img_builtins_shadow.py.
"""LEGB-B: a globals binding shadows the builtins dict entry.

Module-level `len` replaces the builtin; calling it must use the local
function (returns 99), not BI_LEN.
"""


def len(x):
    return 99


def managed_entry():
    return len((1, 2, 3))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
