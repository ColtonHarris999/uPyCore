# Ported from pycore pycore/programs/img_varkw_only.py.
"""CO_VARKEYWORDS only: all keywords go into the dict."""


def f(**k):
    return k["x"] + 10 * k["y"]


def managed_entry():
    return f(x=3, y=4)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
