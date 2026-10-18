# Ported from pycore pycore/programs/img_builtin_len_long_str.py.
"""BI_LEN on LONG_STR (UTF-8 byte length from descriptor)."""


def managed_entry():
    s = "this is a long string!!"
    return len(s)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
