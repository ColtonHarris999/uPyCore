# Ported from pycore pycore/programs/img_call_kw_unexpected.py.
"""CALL_KW unexpected keyword → CALL_FILTER (trap 6)."""


def g(a, b=0):
    return a + b


def managed_entry():
    return g(1, z=9)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
