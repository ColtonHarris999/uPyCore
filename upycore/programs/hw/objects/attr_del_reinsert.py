# Ported from pycore pycore/programs/img_attr_del_reinsert.py.
"""Delete then re-store the same name — tombstone reuse.

"""


def managed_entry():
    del o.x
    o.x = 42
    return o.x


class _o:
    pass
o = _o()
o.x = 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
