# Ported from pycore pycore/programs/img_str_subscr_loop.py.
"""for i in range(len(s)): s[i] — the access pattern a tokenizer needs."""


def managed_entry():
    s = "abcabca"
    hits = 0
    for i in range(len(s)):
        if s[i] == "a":
            hits += 1
    return hits

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
