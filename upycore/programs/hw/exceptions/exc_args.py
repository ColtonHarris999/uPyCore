# Ported from pycore pycore/programs/img_exc_args.py.
"""Read OBK_EXCEPTION.args via LOAD_ATTR. Expected: 2."""


def managed_entry():
    try:
        raise TypeError("x")
    except TypeError as e:
        a = e.args
        n = len(a)
        if a[0] == "x":
            n = n + 1
        return n
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
