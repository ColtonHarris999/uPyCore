# Ported from pycore pycore/programs/img_set_update.py.
"""SET_UPDATE via {*s, *xs} — always excore trap 14. Needs EXCORE_EN=1."""


def managed_entry():
    a = 1
    s = {a}
    xs = [2, 3]
    # Set-display unpack is not in this MicroPython.
    t = set(s)
    t.update(xs)
    n = 0
    if 1 in t:
        n = n + 1
    if 2 in t:
        n = n + 1
    if 3 in t:
        n = n + 1
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
