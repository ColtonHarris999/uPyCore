# Ported from pycore pycore/programs/img_ctor_noinit.py.
"""Type call with no __init__ → bare instance; store and read an attr.

"""


def managed_entry():
    o = T()
    o.x = 7
    return o.x


class T:
    pass

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
