# Ported from pycore pycore/programs/img_call_function_ex.py.
"""CALL_FUNCTION_EX *args with tuple (NULL kwargs)."""


def g(a, b, c):
    return a + 10 * b + 100 * c


def managed_entry():
    return g(*(1, 2, 3))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
