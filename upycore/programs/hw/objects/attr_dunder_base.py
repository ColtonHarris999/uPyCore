# Ported from pycore pycore/programs/img_attr_dunder_base.py.
"""LOAD_ATTR __base__ walks tp_base on OBK_TYPE.

"""


def managed_entry():
    total = 0
    # This MicroPython exposes the base tuple, not a single __base__.
    base = Child.__bases__[0]
    if base is Base:
        total += 1
    if base is not Other:
        total += 2
    if base is not Child:
        total += 4
    return total


class Base:
    pass
class Child(Base):
    pass
class Other:
    pass

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
