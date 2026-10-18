# Ported from pycore pycore/programs/img_bare_raise_no_active.py.
"""Bare raise without an active exception remains fatal PY_TRAP_RAISE (17)."""


def managed_entry():
    raise

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
