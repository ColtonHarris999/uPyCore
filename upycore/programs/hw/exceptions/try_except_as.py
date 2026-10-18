# Ported from pycore pycore/programs/img_try_except_as.py.
"""Bind an exception with ``except T as e`` and complete handler cleanup."""


def managed_entry():
    result = 0
    try:
        raise TypeError
    except TypeError as exc:
        result = 7
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
