# Ported from pycore pycore/programs/img_bound_method_obj.py.
"""Non-method LOAD_ATTR of a TYPE-sourced CODE_OBJECT → OBK_BOUND_METHOD.

"""


def add_one(self, x):
    return x + 1


def managed_entry():
    f = o.m
    return f(1)


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
