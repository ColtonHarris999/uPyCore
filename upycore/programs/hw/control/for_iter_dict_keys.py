# Ported from pycore pycore/programs/img_for_iter_dict_keys.py.
"""DICT iteration yields keys in insertion order. Expected result: 13."""


def managed_entry():
    d = {}
    d[1] = 2
    d[3] = 4
    result = 0
    for key in d:
        result = result * 10 + key
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
