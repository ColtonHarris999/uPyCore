# Ported from pycore pycore/programs/img_dict_str_keys.py.
"""SHORT_STR keys: store, lookup, contains, delete (same-tag)."""


def managed_entry():
    d = {}
    d["a"] = 1
    d["b"] = 2
    d["c"] = 3
    n = d["a"] + d["b"] + d["c"]
    del d["b"]
    if "b" not in d:
        if "a" in d:
            return n + 10
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
