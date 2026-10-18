# Ported from pycore pycore/programs/img_try_lookuperror.py.
"""except LookupError: catches raise KeyError and raise IndexError (Track 1)."""


def managed_entry():
    try:
        raise KeyError
    except LookupError:
        try:
            raise IndexError
        except LookupError:
            return 10

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
