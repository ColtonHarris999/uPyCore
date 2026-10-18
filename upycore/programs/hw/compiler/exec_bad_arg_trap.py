# Ported from pycore pycore/programs/img_exec_bad_arg_trap.py.
"""exec() of a non-code object must trap.

The ROM body calls its argument; CALL on an INT is not a valid callable, so
hardware raises PY_TRAP_CALL_FILTER (6). CPython raises TypeError.
"""


def managed_entry():
    return exec(5)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
