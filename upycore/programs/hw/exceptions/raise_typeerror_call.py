# Ported from pycore pycore/programs/img_raise_typeerror_call.py.
"""Construct and catch a TypeError carrying one positional argument."""


def managed_entry():
    try:
        raise TypeError("x")
    except TypeError:
        return 21

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
