# Ported from pycore pycore/programs/img_default_arg_too_many.py.
"""Too many positionals with defaults present → CALL_FILTER (trap 6)."""


def f(a, b=5):
    return a + b


def managed_entry():
    return f(1, 2, 3)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
