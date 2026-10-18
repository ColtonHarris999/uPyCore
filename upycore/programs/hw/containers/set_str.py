# Ported from pycore pycore/programs/img_set_str.py.
"""Short-string set elements + contains."""


def managed_entry():
    a = "ab"
    b = "cd"
    s = {a, b}
    n = 0
    if "ab" in s:
        n = n + 1
    if "cd" in s:
        n = n + 2
    if "ef" not in s:
        n = n + 4
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
