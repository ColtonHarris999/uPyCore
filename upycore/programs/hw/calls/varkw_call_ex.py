# Ported from pycore pycore/programs/img_varkw_call_ex.py.
"""CALL_FUNCTION_EX with **kwargs packing on the callee."""


def f(a=0, **k):
    return a + len(k) + (0 if len(k) == 0 else k["z"])


def managed_entry():
    d = {"z": 9}
    x = f(*(1,), **d)
    y = f(*(), **{})
    return x + y

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
