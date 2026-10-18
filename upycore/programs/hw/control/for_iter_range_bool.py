# Ported from pycore pycore/programs/img_for_iter_range_bool.py.
"""Image-boot parity coverage for BOOL range arguments."""


def managed_entry():
    count = 0
    for value in range(True):
        count += value + 1
    for value in range(False, True, True):
        count += value + 1
    return count

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
