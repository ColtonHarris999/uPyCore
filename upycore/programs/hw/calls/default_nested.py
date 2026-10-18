# Ported from pycore pycore/programs/img_default_nested.py.
"""Nested all-default calls (outer and inner both argc==0)."""


def inner(y=4):
    return y


def outer(x=3):
    return x + inner()


def managed_entry():
    return outer() + outer(10)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
