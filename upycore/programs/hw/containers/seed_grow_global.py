# Ported from pycore pycore/programs/img_seed_grow_global.py.
"""SEED_INSTANCE STORE_ATTR grow then LOAD_GLOBAL — globals must survive.

"""

MARKER = 99


def managed_entry():
    o.a = 1
    o.b = 2
    o.c = 3
    o.d = 4
    return MARKER


class _o:
    pass
o = _o()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
