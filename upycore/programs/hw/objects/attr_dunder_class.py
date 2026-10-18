# Ported from pycore pycore/programs/img_attr_dunder_class.py.
"""LOAD_ATTR __class__ returns the instance's OBK_TYPE.

TYPE.__class__ → self on pycore (not host ``type``); only instances are
compared against the host golden.

"""


def managed_entry():
    if o.__class__ is T:
        return 1
    return 0


class T:
    pass
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
