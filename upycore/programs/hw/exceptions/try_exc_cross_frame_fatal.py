# Ported from pycore pycore/programs/img_try_exc_cross_frame_fatal.py.
"""An exception raised in a callee reaches the caller's matching handler."""


def fail():
    raise ValueError


def managed_entry():
    try:
        fail()
    except ValueError:
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
