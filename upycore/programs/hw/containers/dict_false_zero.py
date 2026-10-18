# Ported from pycore pycore/programs/img_dict_false_zero.py.
"""False / 0 cross-tag contains + subscript via pycore rich_eq.

Store INT 0, then False in d / d[False] → 7 (single-core).
"""


def managed_entry():
    d = {}
    d[0] = 7
    if False in d:
        return d[False]
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
