# Ported from pycore pycore/programs/img_set_bool_int.py.
"""Rich equality on set: add 1, check True in s (pycore, no excore)."""


def managed_entry():
    a = 1
    s = {a}
    if True in s:
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
