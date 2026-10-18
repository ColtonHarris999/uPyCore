# Ported from pycore pycore/programs/img_method_nested.py.
"""Nested bound calls: self._a(self._b(x)).

"""


def meth_b(self, x):
    return x + 1


def meth_a(self, x):
    return x * 2


def managed_entry():
    return o._a(o._b(3))


class T:
    pass
T._a = meth_a
T._b = meth_b
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
