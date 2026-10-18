# Ported from pycore pycore/programs/img_print_star_kw.py.
"""print(*xs, sep=) via CALL_FUNCTION_EX + kwargs."""


def managed_entry():
    xs = (1, 2, 3)
    print(*xs, sep="-")
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
