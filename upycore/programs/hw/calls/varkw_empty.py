# Ported from pycore pycore/programs/img_varkw_empty.py.
"""CO_VARKEYWORDS: empty **k when no leftover keywords (incl. argc==0)."""


def f(**k):
    return len(k)


def g(a=7, **k):
    return a + len(k)


def managed_entry():
    # f()→0, g()→7, g(9)→9
    return f() + g() + g(9)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
