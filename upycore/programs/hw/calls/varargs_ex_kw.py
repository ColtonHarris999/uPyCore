# Ported from pycore pycore/programs/img_varargs_ex_kw.py.
"""CO_VARARGS + CALL_FUNCTION_EX kwargs; fills remaining kw-only defaults."""


def f(*a, x=1, y=2):
    return len(a) * 1000 + x * 100 + y


def managed_entry():
    xs = (7, 8)
    return f(*xs, x=3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
