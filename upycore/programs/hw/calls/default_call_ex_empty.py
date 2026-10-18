# Ported from pycore pycore/programs/img_default_call_ex_empty.py.
"""All-defaults via CALL_FUNCTION_EX empty *args / **kwargs."""


def f(a=None, b=0):
    if a is None:
        return 10 + b
    return a + b


def managed_entry():
    x = f(*())
    y = f(*[], **{})
    z = f(*(7,), **{"b": 1})
    return x + y + z

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
