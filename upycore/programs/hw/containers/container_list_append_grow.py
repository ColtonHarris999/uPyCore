# Ported from pycore pycore/programs/list_append_grow.py.
"""List comprehension that grows via LIST_APPEND.

The container accelerator grows the buffer on the pycore side. Expected
result: INT 7.
"""


def managed_entry():
    xs = [i for i in range(8)]
    return xs[7]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
