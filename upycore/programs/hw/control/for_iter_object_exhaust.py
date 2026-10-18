# Ported from pycore pycore/programs/img_for_iter_object_exhaust.py.
"""Empty object iterator exhausts without body execution.

"""


def iter_self(self):
    return self


def next_empty(self):
    raise StopIteration


def managed_entry():
    total = 7
    for x in o:
        total += 100
    return total


class T:
    pass
T.__iter__ = iter_self
T.__next__ = next_empty
o = T()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
