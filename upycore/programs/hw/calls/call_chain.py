# Ported from pycore pycore/programs/img_call_chain.py.
def add(a, b):
    return a + b


def double(x):
    return add(x, x)


def managed_entry():
    return double(21)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
