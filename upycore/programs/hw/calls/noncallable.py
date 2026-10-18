# Ported from pycore pycore/programs/img_noncallable.py.
def managed_entry():
    x = 5
    return x()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
