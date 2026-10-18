# Ported from pycore pycore/programs/img_set_hash_neg1.py.
"""hash(-1)==-2 and hash(-2) coexist; both present via CONTAINS."""


def managed_entry():
    a = -1
    b = -2
    s = {a, b}
    n = 0
    if -1 in s:
        n = n + 1
    if -2 in s:
        n = n + 2
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
