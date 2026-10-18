# Ported from pycore pycore/programs/img_default_arg.py.
"""Defaults folded at image-build time via SET_FUNCTION_ATTRIBUTE."""


def f(a, b=5):
    return a + b


def managed_entry():
    return f(1) + f(1, 2)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
