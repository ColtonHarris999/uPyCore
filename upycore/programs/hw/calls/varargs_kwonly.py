# Ported from pycore pycore/programs/img_varargs_kwonly.py.
"""CO_VARARGS with keyword-only binding through CALL_KW."""


def f(*a, s=1):
    return len(a) * 10 + s


def managed_entry():
    return f(9, s=2)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
