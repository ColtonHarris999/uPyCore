# Ported from pycore pycore/programs/img_firmware_isinstance.py.
"""ROM isinstance / issubclass via __class__ / __base__ specials.

"""


def managed_entry():
    total = 0
    if isinstance(o, Child):
        total += 1
    if isinstance(o, Base):
        total += 2
    if not isinstance(o, Other):
        total += 4
    if issubclass(Child, Base):
        total += 8
    if issubclass(Child, Child):
        total += 16
    if not issubclass(Base, Child):
        total += 32
    if not issubclass(Other, Base):
        total += 64
    return total


class Base:
    pass
class Child(Base):
    pass
class Other:
    pass
o = Child()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
