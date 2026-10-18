# Ported from pycore pycore/programs/img_class_const.py.
"""M4: class-level constant attribute (WSIZE = 8)."""


class C:
    WSIZE = 8

    def get_wsize(self):
        return self.WSIZE


def managed_entry():
    return C().get_wsize()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
