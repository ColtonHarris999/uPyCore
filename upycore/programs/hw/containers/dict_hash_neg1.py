# Ported from pycore pycore/programs/img_dict_hash_neg1.py.
"""INT keys -1 and -2 share CPython hash (-2) but remain distinct keys.

Same-tag probe continues past unequal match; both entries stay present.
"""


def managed_entry():
    d = {}
    d[-1] = 10
    d[-2] = 20
    return d[-1] + d[-2]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
