# Ported from pycore pycore/programs/img_set_grow_basic.py.
"""SET_ADD past 2/3 load → SET_GROW, then verify contains. Needs EXCORE_EN=1."""



def managed_entry():
    s = set()
    s.add(0)
    s.add(1)
    s.add(2)
    s.add(3)
    n = 0
    if 0 in s:
        n = n + 1
    if 1 in s:
        n = n + 1
    if 2 in s:
        n = n + 1
    if 3 in s:
        n = n + 1
    if 4 not in s:
        n = n + 1
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
