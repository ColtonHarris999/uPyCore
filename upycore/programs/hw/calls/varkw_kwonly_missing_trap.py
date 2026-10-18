# Ported from pycore pycore/programs/img_varkw_kwonly_missing_trap.py.
"""Required kw-only missing while extras would go to **kwargs → CALL_FILTER."""


def f(*, x, **k):
    return x + len(k)


def managed_entry():
    return f(y=1)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
