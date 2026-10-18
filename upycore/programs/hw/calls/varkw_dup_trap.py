# Ported from pycore pycore/programs/img_varkw_dup_trap.py.
"""Positional + keyword for the same formal with **kwargs → CALL_FILTER.

CPython: TypeError multiple values for argument. Leftover packing must not
swallow the duplicate.
"""


def f(a, **k):
    return a + len(k)


def managed_entry():
    return f(1, a=2)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
