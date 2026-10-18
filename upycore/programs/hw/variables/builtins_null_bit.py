# Ported from pycore pycore/programs/img_builtins_null_bit.py.
"""LEGB-B: LOAD_GLOBAL with null bit set after a builtins hit.

`max(3, 7)` emits LOAD_GLOBAL (null+name) then CALL; null-bit push must
work when the value came from the builtins dict fallback.
"""


def managed_entry():
    return max(3, 7)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
