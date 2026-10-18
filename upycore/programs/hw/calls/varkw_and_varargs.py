# Ported from pycore pycore/programs/img_varkw_and_varargs.py.
"""*args + **kwargs together (scratch/index regression)."""


def f(a, *rest, **k):
    return a + 10 * len(rest) + 100 * len(k) + (0 if len(k) == 0 else k["z"])


def managed_entry():
    # f(1,2,3,z=4) → 1 + 20 + 100 + 4 = 125
    return f(1, 2, 3, z=4) + f(5)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
