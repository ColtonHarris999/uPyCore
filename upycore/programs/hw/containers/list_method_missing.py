# Ported from pycore pycore/programs/img_list_method_missing.py.
"""Missing method on a list → PY_TRAP_ATTR_ERROR (15)."""


def managed_entry():
    xs = []
    return xs.foo

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
