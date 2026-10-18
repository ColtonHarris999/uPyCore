# Ported from pycore pycore/programs/img_for_iter_object_nested.py.
"""Nested object for-loops (list-returning __iter__).

"""


def iter_list(self):
    a = 1
    b = 2
    # MicroPython requires __iter__ to return an iterator, not a list.
    return iter([a, b])


def managed_entry():
    total = 0
    for x in o:
        for y in p:
            total += x * y
    return total


class T:
    pass
T.__iter__ = iter_list
o = T()
p = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
