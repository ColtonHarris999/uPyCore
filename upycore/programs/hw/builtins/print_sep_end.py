# Ported from pycore pycore/programs/img_print_sep_end.py.
"""print kwargs: sep= and end= via CALL_KW."""


def managed_entry():
    print(1, 2, sep=",", end=";")
    print(3, end="")
    print()
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
