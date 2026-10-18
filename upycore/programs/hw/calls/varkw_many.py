# Ported from pycore pycore/programs/img_varkw_many.py.
"""Risk: pre-sized dict holds many leftovers without DICT_GROW."""


def f(**k):
    return len(k)


def managed_entry():
    return f(a=1, b=2, c=3, d=4, e=5, f=6, g=7, h=8)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
