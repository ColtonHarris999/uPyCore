# Ported from pycore pycore/programs/img_varkw_name_collision.py.
"""Keyword named like *args goes into **kwargs (not the varargs tuple)."""


def f(*args, **kwargs):
    return len(args) + 10 * len(kwargs) + (0 if len(kwargs) == 0 else kwargs["args"])


def managed_entry():
    # g(1, 2, args=3) → args=(1,2), kwargs={'args':3} → 2+10+3=15
    return f(1, 2, args=3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
