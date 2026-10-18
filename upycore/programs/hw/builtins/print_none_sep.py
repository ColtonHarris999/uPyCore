# Ported from pycore pycore/programs/img_print_none_sep.py.
"""None and SHORT_STR mixed with custom sep."""


def managed_entry():
    print(None, "x", None, sep=":")
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
