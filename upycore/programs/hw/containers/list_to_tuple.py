# Ported from pycore pycore/programs/img_list_to_tuple.py.
# CALL_INTRINSIC_1 arg 6 (INTRINSIC_LIST_TO_TUPLE) from starred tuple display.


def managed_entry():
    x = 1
    lst = [x, 2, 3]
    # Starred tuple display is not in this MicroPython.
    t = tuple(lst)
    return t[0] + t[1] + t[2]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
