# Ported from pycore pycore/programs/img_for_iter_dict_str_keys.py.
"""DICT iteration preserves SHORT_STR/LONG_STR insertion order."""


def managed_entry():
    d = {}
    d["a"] = 1
    d["abcdefghijklmnopqrst"] = 2
    result = 0
    for key in d:
        result = d[key]
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
