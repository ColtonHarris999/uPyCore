# Ported from pycore pycore/programs/img_for_iter_dict_delete.py.
"""Deleting a key during DICT iteration trips the version guard."""


def managed_entry():
    d = {1: 2, 3: 4}
    result = 0
    for key in d:
        result += key
        del d[3]
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
