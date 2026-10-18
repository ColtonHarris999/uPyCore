# Ported from pycore pycore/programs/img_list_method_unbound.py.
"""Unbound native method form: f = xs.append; f(7). Two-core. Expected: 7."""


def managed_entry():
    xs = []
    f = xs.append
    f(7)
    return xs[0]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
