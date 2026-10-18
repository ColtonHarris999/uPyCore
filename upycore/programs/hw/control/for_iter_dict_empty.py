# Ported from pycore pycore/programs/img_for_iter_dict_empty.py.
"""An empty DICT exhausts immediately. Expected result: 7."""


def managed_entry():
    result = 7
    for key in {}:
        result += key
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
