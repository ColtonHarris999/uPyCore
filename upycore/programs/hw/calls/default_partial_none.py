# Ported from pycore pycore/programs/img_default_partial_none.py.
"""Trailing None default with one required positional (non-wipe path)."""


def f(a, b=None):
    if b is None:
        return a + 10
    return a + b


def managed_entry():
    return f(1) + f(1, None) + f(1, 2)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
