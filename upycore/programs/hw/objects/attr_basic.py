# Ported from pycore pycore/programs/img_attr_basic.py.
"""STORE_ATTR then LOAD_ATTR on a seeded instance __dict__.

"""


def managed_entry():
    o.x = 5
    o.y = 7
    return o.x + o.y


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
