# Ported from pycore pycore/programs/img_firmware_tuple_empty.py.
"""ROM tuple() with no args must return empty (None-default CALL fill).

Avoid list literals that emit LIST_EXTEND (needs excore). Iterable materialize
is covered by img_firmware_wave3_containers.

Host golden: 101.
"""


def managed_entry():
    t = tuple()
    total = 0
    if len(t) == 0:
        total += 100
    # tuple(None) is not an empty tuple here; None is not iterable.
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
