# Ported from pycore pycore/programs/img_firmware_attr_helpers.py.
"""ROM getattr / hasattr / setattr / delattr via __dict__ special.

"""


def managed_entry():
    total = 0
    setattr(o, "x", 11)
    if getattr(o, "x") == 11:
        total += 1
    if hasattr(o, "x"):
        total += 2
    if not hasattr(o, "missing"):
        total += 4
    if getattr(o, "missing", 99) == 99:
        total += 8
    delattr(o, "x")
    if not hasattr(o, "x"):
        total += 16
    return total


class _o:
    pass
o = _o()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
