# Ported from pycore pycore/programs/img_exec_globals_type_trap.py.
"""exec(code, non-dict) is PY_TRAP_TYPE (1). CPython raises TypeError.

"""


def managed_entry():
    return exec(payload, 5)


payload = compile('x = 1', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
