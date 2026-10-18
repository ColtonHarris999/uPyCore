# Ported from pycore pycore/programs/img_varargs_call_ex.py.
"""CO_VARARGS with CALL_FUNCTION_EX star expansion."""


def f(*a):
    return len(a)


def managed_entry():
    return f(*(1, 2))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
