# Ported from pycore pycore/programs/img_attr_shadow.py.
"""Instance attribute shadows a same-named class attribute.

"""


def managed_entry():
    return o.x


class T:
    x = 99
o = T()
o.x = 5

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
