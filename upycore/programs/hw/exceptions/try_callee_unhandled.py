# Ported from pycore pycore/programs/img_try_callee_unhandled.py.
"""An exception unhandled through the module frame remains trap 17."""


def fail():
    raise ValueError



try:
    fail()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
