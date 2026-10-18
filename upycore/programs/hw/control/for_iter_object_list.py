# Ported from pycore pycore/programs/img_for_iter_object_list.py.
"""GET_ITER object → __iter__ returns list → native FOR_ITER.

"""


def iter_list(self):
    a = 1
    b = 2
    c = 3
    # MicroPython requires __iter__ to return an iterator, not a list.
    return iter([a, b, c])


def managed_entry():
    total = 0
    for x in o:
        total += x
    return total


class T:
    pass
T.__iter__ = iter_list
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
