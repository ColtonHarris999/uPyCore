# Ported from pycore pycore/programs/img_print_star.py.
"""print(*xs) via CALL_FUNCTION_EX."""


def managed_entry():
    xs = (10, 20, 30)
    print(*xs)
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
