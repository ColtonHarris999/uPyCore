# Ported from pycore pycore/programs/img_delete_fast_unbound.py.
# Negative: second DELETE_FAST on an already-cleared local must trap.
#
# CPython raises UnboundLocalError; PyCore traps PY_TRAP_MEM_FAULT (7).
# Host execution raises, so this uses PYCORE_IMAGE_TRAP_RUN (no EXPECTED_*).


def managed_entry():
    x = 1
    del x
    del x
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
