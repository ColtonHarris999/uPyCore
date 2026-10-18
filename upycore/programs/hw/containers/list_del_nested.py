# Ported from pycore pycore/programs/img_list_del_nested.py.
"""Nested list handles survive DELETE_SUBSCR of a sibling slot.

outer = [[11], [22], [33]]; del outer[1] → [[11], [33]];
return outer[0][0] + outer[1][0] = 44.
"""


def managed_entry():
    a = [11]
    b = [22]
    c = [33]
    outer = [a, b, c]
    del outer[1]
    return outer[0][0] + outer[1][0]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
