# Ported from pycore pycore/programs/img_list_concat_type_trap.py.
"""Mixed LIST+TUPLE is not sequence-concat; still PY_TRAP_TYPE (1)."""


def managed_entry():
    return [1] + (2,)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
