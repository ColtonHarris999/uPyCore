# Ported from pycore pycore/programs/img_for_iter_object_raise_catch.py.
"""A non-StopIteration protocol exception unwinds to the bytecode handler.

"""


def iter_self(self):
    return self


def next_t(self):
    raise ValueError


def managed_entry():
    try:
        for x in o:
            return x
    except ValueError:
        return 1
    return 0


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
