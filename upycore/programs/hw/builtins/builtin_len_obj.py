# Ported from pycore pycore/programs/img_builtin_len_obj.py.
"""BI_LEN miss path: INSTANCE with __len__ on its type's tp_dict.

"""


def box_len(self):
    return 5


def managed_entry():
    b = Box()
    return len(b)


class Box:
    pass
Box.__len__ = box_len

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
