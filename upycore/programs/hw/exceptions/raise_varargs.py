# Ported from pycore pycore/programs/img_raise_varargs.py.
"""RAISE_VARARGS oparg=1 of a non-exception int → PY_TRAP_TYPE (1)."""


def managed_entry():
    e = 1
    raise e

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
