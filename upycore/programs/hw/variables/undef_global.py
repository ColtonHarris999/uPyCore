# Ported from pycore pycore/programs/img_undef_global.py.
def managed_entry():
    return missing_global()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
