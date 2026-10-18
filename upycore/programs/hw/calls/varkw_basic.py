# Ported from pycore pycore/programs/img_varkw_basic.py.
"""CO_VARKEYWORDS: leftover kwargs packed into **k dict."""


def f(a, **k):
    return a + 10 * len(k) + (0 if len(k) == 0 else k["b"] + k["c"])


def managed_entry():
    # f(1,b=2,c=3) → 1 + 20 + 5 = 26
    return f(1, b=2, c=3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
