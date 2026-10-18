# Ported from pycore pycore/programs/img_complex_type_trap.py.
"""complex() with a complex component is PY_TRAP_TYPE (trap 1).

CPython raises TypeError for complex(1, 1j). No string form here.
"""


def managed_entry():
    return complex(1, 1j)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
