# Ported from pycore pycore/programs/img_varargs_empty.py.
"""CO_VARARGS: no excess positionals produces an empty *a tuple."""


def f(*a):
    return len(a)


def managed_entry():
    return f()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
