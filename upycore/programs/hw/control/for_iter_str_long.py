# Ported from pycore pycore/programs/img_for_iter_str_long.py.
"""LONG_STR literals iterate once per UTF-8 code point."""


def managed_entry():
    total = 0
    for c in "this is a long string!!":
        total += 1
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
