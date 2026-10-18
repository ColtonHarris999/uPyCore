# Ported from pycore pycore/programs/img_for_iter_set_basic.py.
"""set(LIST/TUPLE) deduplicates and iterates elements. Expected sum: 15."""


def managed_entry():
    a = 1
    b = 2
    c = 3
    values = [a, b, a, c]
    s = set(values)
    result = 0
    for value in s:
        result += value
    for value in set((4, 5, 4)):
        result += value
    return result

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
