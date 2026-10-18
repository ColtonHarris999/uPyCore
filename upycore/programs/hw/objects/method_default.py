# Ported from pycore pycore/programs/img_method_default.py.
"""Bound method with positional default; o.m() supplies only self.

"""


def add_n(self, n=5):
    return n + 1


def managed_entry():
    return o.m() + o.m(2)


class T:
    pass
T.m = add_n
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
