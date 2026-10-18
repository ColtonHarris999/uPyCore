# Ported from pycore pycore/programs/img_ctor_init.py.
"""Type call runs __init__; return instance (ret_discard_push_self), not None.

"""


def init_t(self):
    self.x = 11


def managed_entry():
    o = T()
    return o.x


class T:
    pass
T.__init__ = init_t

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
