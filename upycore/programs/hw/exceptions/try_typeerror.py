# Ported from pycore pycore/programs/img_try_typeerror.py.
"""except Exception: catches raise TypeError as a bare type (Track 1 + T5-A)."""


def managed_entry():
    try:
        raise TypeError
    except Exception:
        return 8

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
