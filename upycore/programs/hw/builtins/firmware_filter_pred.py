# Ported from pycore pycore/programs/img_firmware_filter_pred.py.
"""filter with a predicate CODE_OBJECT (two-core). Host golden: 9."""


def positive(x):
    return x > 0


def managed_entry():
    a = -1
    b = 2
    c = 0
    d = 7
    xs = [a, b, c, d]
    out = filter(positive, xs)
    total = 0
    for v in out:
        total += v
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
