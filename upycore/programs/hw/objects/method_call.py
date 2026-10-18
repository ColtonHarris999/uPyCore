# Ported from pycore pycore/programs/img_method_call.py.
"""Bound-method form: o.m(1) → LOAD_ATTR|1 + CALL 1 (no BM allocation).

"""


def add_one(self, x):
    return x + 1


def managed_entry():
    return o.m(1)


class T:
    pass
T.m = add_one
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
