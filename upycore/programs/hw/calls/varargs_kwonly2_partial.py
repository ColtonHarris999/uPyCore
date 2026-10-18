# Ported from pycore pycore/programs/img_varargs_kwonly2_partial.py.
"""CO_VARARGS + two kw-only; override only the first kw-only name."""


def f(*a, x=1, y=2):
    return len(a) * 1000 + x * 100 + y


def managed_entry():
    return f(7, 8, x=3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
