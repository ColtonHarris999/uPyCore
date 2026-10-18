# Ported from pycore pycore/programs/img_call_function_ex_kw.py.
"""CALL_FUNCTION_EX with DICT_MERGE empty-dest **kwargs path."""


def h(a, b=0):
    return a + 10 * b


def managed_entry():
    return h(*(1,), **{"b": 2}) + h(*[], **{"a": 5, "b": 3})

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
