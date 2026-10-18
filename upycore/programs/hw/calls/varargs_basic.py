# Ported from pycore pycore/programs/img_varargs_basic.py.
"""CO_VARARGS: excess positional arguments are packed into *a."""


def f(*a):
    return len(a)


def managed_entry():
    return f(1, 2, 3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
