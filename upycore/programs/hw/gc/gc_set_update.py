# Ported from pycore pycore/programs/img_gc_set_update.py.
"""SET_UPDATE TUPLE source only (G9 row 16). No dict traffic to steal the run."""


def managed_entry():
    total = 0
    keep = {0}
    for i in range(400):
        st = (i + 1, i + 2, i + 3, i + 4)
        # Set-display unpack is not in this MicroPython.
        keep = set(st)
        total = total + len(keep)
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
