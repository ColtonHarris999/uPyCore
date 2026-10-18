# Ported from pycore pycore/programs/img_dict_del_trap.py.
"""DELETE_SUBSCR on a dict — same-tag tombstone path (returns 0)."""


def managed_entry():
    d = {}
    d["k"] = 1
    del d["k"]
    # Miss after delete should not revive the key; return 0 on success.
    if "k" in d:
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
