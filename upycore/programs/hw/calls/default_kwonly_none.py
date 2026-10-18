# Ported from pycore pycore/programs/img_default_kwonly_none.py.
"""Kw-only None default with no positionals (CALL_KW binder path)."""


def f(*, x=None):
    if x is None:
        return 1
    return 0


def managed_entry():
    return f() * 10 + f(x=None) * 1 + f(x=2)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
