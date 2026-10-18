# Ported from pycore pycore/programs/img_raise_instance.py.
"""Raise and catch an already-constructed exception instance."""


def managed_entry():
    e = TypeError("x")
    try:
        raise e
    except TypeError:
        return 22

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
