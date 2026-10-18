# Ported from pycore pycore/programs/img_load_fast_check_unbound.py.
# Negative: LOAD_FAST_CHECK on an unbound local must trap.
#
# CPython raises UnboundLocalError; PyCore traps PY_TRAP_MEM_FAULT (7).
# Host execution raises, so this uses PYCORE_IMAGE_TRAP_RUN (no EXPECTED_*).


def managed_entry():
    x = 1
    del x
    return x

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
