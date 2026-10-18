# Ported from pycore pycore/programs/img_method_call_kw.py.
"""Bound method + CALL_KW (no **kwargs): self must not steal kwargs slots.

"""


def add(self, a, b=0):
    return a + 10 * b


def managed_entry():
    # o.m(1, b=2) → 21; o.m(b=3, a=4) → 34
    return o.m(1, b=2) + o.m(b=3, a=4)


class T:
    pass
T.m = add
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
