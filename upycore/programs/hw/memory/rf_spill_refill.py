# Ported from pycore pycore/programs/img_rf_spill_refill.py.
# Caller locals must survive a callee deep enough to spill the caller's window.


def inner(n):
    if n <= 0:
        return 0
    return inner(n - 1) + 1


def outer():
    x = 42
    y = 17
    z = inner(16)
    return x + y + z


def managed_entry():
    return outer()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
