# Ported from pycore pycore/programs/img_firmware_min_varargs.py.
"""3+/4-arg min() — CALL ceiling from issue #76 OSS edit_distance.

TheAlgorithms edit_distance returns min(sub, ins, delete). Firmware used
to be ``min(a, b=None)`` so argc=3 was TypeError / image-reject.

Host golden: 3 + 2 + 4 + 1 = 10
"""


def managed_entry():
    total = 0
    total += min(8, 3, 5)
    total += min(7, 9, 2, 8)
    total += min(9, 4)
    # Tie keeps the first argument (CPython).
    total += min(1, 1, 4)
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
