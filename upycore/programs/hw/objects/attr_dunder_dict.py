# Ported from pycore pycore/programs/img_attr_dunder_dict.py.
"""LOAD_ATTR __dict__ returns the live instance dict handle.

"""


def managed_entry():
    o.x = 5
    o.y = 7
    d = o.__dict__
    return d["x"] + d["y"]


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
