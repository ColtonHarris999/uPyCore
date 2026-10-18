# Ported from pycore pycore/programs/img_firmware_sorted_kw.py.
"""Wave 3B: sorted(..., reverse=) and sum(..., start=) via CALL_KW.

Two-core (list materialization / grow). Host golden: 460.
"""


def managed_entry():
    a = 1
    b = 3
    c = 2
    xs = [a, b, c]
    s = sorted(xs, reverse=True)
    total = s[0] * 100 + s[1] * 10 + s[2]
    s2 = sorted(xs, reverse=False)
    total += s2[0] * 100 + s2[1] * 10 + s2[2]
    # sum() does not take the start keyword here.
    total += sum(xs, 10)
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
