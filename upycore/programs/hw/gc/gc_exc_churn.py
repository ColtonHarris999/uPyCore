# Ported from pycore pycore/programs/img_gc_exc_churn.py.
"""CALL exception TYPE (G9 row 28) as the only heap producer in the loop."""


def one_exc():
    try:
        raise ValueError("exc-payload-long-enough")
    except ValueError as ex:
        return len(ex.args)


def managed_entry():
    total = 0
    for i in range(800):
        total = total + one_exc()
        total = total + i
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
