# Ported from pycore pycore/programs/img_for_iter_str_empty.py.
"""Empty strings exhaust on the first FOR_ITER."""


def managed_entry():
    total = 0
    for c in "":
        total += 1
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
