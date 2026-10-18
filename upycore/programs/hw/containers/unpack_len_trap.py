# Ported from pycore pycore/programs/img_unpack_len_trap.py.
"""UNPACK_SEQUENCE length mismatch must raise PY_TRAP_TYPE (trap 1)."""


def managed_entry():
    t = (1,)
    a, b = t
    return a

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
