# Ported from pycore pycore/programs/img_builtin_len_obj_missing.py.
"""BI_LEN on INSTANCE without __len__ → PY_TRAP_ATTR_ERROR (15).

"""


def managed_entry():
    e = Empty()
    return len(e)


class Empty:
    pass

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
