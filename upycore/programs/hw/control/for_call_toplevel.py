# Ported from pycore pycore/programs/img_for_call_toplevel.py.
"""Call a function from a module-level for loop.

The same call inside a function or a while loop already ran. Expected
result: 9 (1+1 + 2+1 + 3+1).
"""


def g(n):
    return n + 1


acc = 0
for i in [1, 2, 3]:
    acc = acc + g(i)


def managed_entry():
    return acc

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
