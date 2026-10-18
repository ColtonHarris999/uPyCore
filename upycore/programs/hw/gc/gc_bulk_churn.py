# Ported from pycore pycore/programs/img_gc_bulk_churn.py.
"""SET_UPDATE / DICT_UPDATE / DICT_MERGE (G9 rows 16-18) on EXCORE_EN=0.

Sources are computed so CPython cannot fold them into BUILD_SET / BUILD_MAP.
Empty dest + four elems grows the table on the pycore bulk path.
"""


def _kwmerge(**kw):
    return len(kw)


def managed_entry():
    total = 0
    keep_s = {0}
    keep_d = {"z": 0}
    for i in range(160):
        st = (i + 1, i + 2, i + 3, i + 4)
        # Display unpack is not in this MicroPython. set() and update() build the same objects.
        keep_s = set(st)
        da = {"a": i + 1, "b": i + 2}
        db = {"c": i + 3, "d": i + 4, "e": i + 5}
        keep_d = {}
        keep_d.update(da)
        keep_d.update(db)
        total = total + len(keep_s) + len(keep_d)
        merged = {"a": i + 1, "b": i + 2}
        merged.update({"c": i + 3, "d": i + 4})
        total = total + _kwmerge(**merged)
    return total + len(keep_s) + keep_d["e"]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
