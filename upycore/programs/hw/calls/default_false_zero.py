# Ported from pycore pycore/programs/img_default_false_zero.py.
"""All-defaults False / 0 survive argc==0 frame init."""


def f(a=False):
    if a is False:
        return 1
    return 0


def g(a=0):
    return a + 7


def managed_entry():
    return f() + g() + g(3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
