# Ported from pycore pycore/programs/img_bare_raise.py.
"""A bare raise reuses the active exception and reaches an outer handler."""


def managed_entry():
    try:
        try:
            raise TypeError
        except TypeError:
            raise
    except TypeError:
        return 13
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
