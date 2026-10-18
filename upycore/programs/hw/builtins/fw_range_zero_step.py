# Ported from pycore pycore/programs/img_fw_range_zero_step.py.
"""Firmware range() raises catchable ValueError for a zero step."""


def range(start, stop=None, step=1):
    # Image-local firmware body: the production builtins entry uses BI_RANGE.
    if stop is None:
        stop = start
        start = 0
    if step == 0:
        raise ValueError
    out = []
    i = start
    if step > 0:
        while i < stop:
            out += [i]
            i = i + step
    else:
        while i > stop:
            out += [i]
            i = i + step
    return out


def managed_entry():
    try:
        range(0, 1, 0)
    except ValueError:
        return 41
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
