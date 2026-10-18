# Ported from pycore pycore/programs/img_default_arg_argc_trap.py.
"""Too few args even with defaults → PY_TRAP_CALL_FILTER."""


def f(a, b=5):
    return a + b


def managed_entry():
    return f()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
