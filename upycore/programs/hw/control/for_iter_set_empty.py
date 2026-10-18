# Ported from pycore pycore/programs/img_for_iter_set_empty.py.
"""set() builds an empty SET that exhausts immediately."""


def managed_entry():
    result = 7
    for value in set():
        result += value
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
