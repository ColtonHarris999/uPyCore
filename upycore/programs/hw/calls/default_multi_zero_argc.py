# Ported from pycore pycore/programs/img_default_multi_zero_argc.py.
"""Multiple positional defaults with zero supplied args."""


def f(a=1, b=2, c=3):
    return a * 100 + b * 10 + c


def managed_entry():
    return f() + f(9) + f(9, 8)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
