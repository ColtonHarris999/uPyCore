# Ported from pycore pycore/programs/img_varargs_pos_defaults.py.
"""Positional defaults before *args; include argc==0 fill."""


def f(a=9, *rest):
    return a + 10 * len(rest)


def managed_entry():
    return f() + f(1) + f(1, 2, 3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
