# Ported from pycore pycore/programs/img_for_iter_dict_grow.py.
"""DICT_GROW rehash preserves insertion-order sidecar. Expected: 1234."""


def managed_entry():
    d = {}
    d[1] = 10
    d[2] = 20
    d[3] = 30
    d[4] = 40
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
