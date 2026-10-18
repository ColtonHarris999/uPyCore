# Ported from pycore pycore/programs/img_attr_overwrite.py.
"""STORE_ATTR twice on the same name — upsert, used unchanged.

"""


def managed_entry():
    o.x = 1
    o.x = 9
    return o.x


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
