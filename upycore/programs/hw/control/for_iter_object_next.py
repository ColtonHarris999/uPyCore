# Ported from pycore pycore/programs/img_for_iter_object_next.py.
"""HEAP_ITER: __iter__ returns self; __next__ yields then StopIteration.

"""


def iter_self(self):
    self.i = 0
    return self


def next_t(self):
    i = self.i
    if i >= 3:
        raise StopIteration
    self.i = i + 1
    return i + 1


def managed_entry():
    total = 0
    for x in o:
        total += x
    return total


class T:
    pass
T.__iter__ = iter_self
T.__next__ = next_t
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
