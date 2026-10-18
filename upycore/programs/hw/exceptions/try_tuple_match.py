# Ported from pycore pycore/programs/img_try_tuple_match.py.
"""except (StopIteration, ValueError): tuple handler (Track 1)."""


def managed_entry():
    try:
        raise ValueError
    except (StopIteration, ValueError):
        return 9

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
