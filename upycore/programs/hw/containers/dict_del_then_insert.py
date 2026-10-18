# Ported from pycore pycore/programs/img_dict_del_then_insert.py.
"""Delete then reinsert the same key (tombstone reuse on pycore)."""


def managed_entry():
    d = {}
    d[1] = 10
    d[2] = 20
    d[3] = 30
    del d[2]
    d[2] = 40
    return d[1] + d[2] + d[3]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
