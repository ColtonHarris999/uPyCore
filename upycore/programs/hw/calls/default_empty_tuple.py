# Ported from pycore pycore/programs/img_default_empty_tuple.py.
"""Empty-tuple positional default filled when argc==0."""


def f(a=()):
    return len(a) + 3


def managed_entry():
    return f() + f((1, 2))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
