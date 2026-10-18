# Ported from pycore pycore/programs/img_varkw_method.py.
"""Bound method with **kwargs (self + leftover packing).

"""


def add_kw(self, a=0, **k):
    return a + 10 * len(k) + (0 if len(k) == 0 else k["x"])


def managed_entry():
    # o.m(1, x=2) → 1 + 10 + 2 = 13; o.m() → 0
    return o.m(1, x=2) + o.m()


class T:
    pass
T.m = add_kw
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
