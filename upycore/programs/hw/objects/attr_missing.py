# Ported from pycore pycore/programs/img_attr_missing.py.
"""LOAD_ATTR on an absent name → PY_TRAP_ATTR_ERROR (15).

"""


def managed_entry():
    return o.missing


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
