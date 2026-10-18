# Ported from pycore pycore/programs/img_bad_argc.py.
def add(a, b):
    return a + b


def managed_entry():
    return add(1)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
