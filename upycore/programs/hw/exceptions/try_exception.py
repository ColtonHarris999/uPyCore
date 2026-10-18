# Ported from pycore pycore/programs/img_try_exception.py.
"""except Exception: catches raise StopIteration (MRO, Track 1)."""


def managed_entry():
    try:
        raise StopIteration
    except Exception:
        return 7

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
