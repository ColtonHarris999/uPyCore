# Ported from pycore pycore/programs/img_attr_mro.py.
"""Attribute found on the type, not the instance.

"""


def managed_entry():
    return o.x


class T:
    x = 99
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
