# Ported from pycore pycore/programs/img_str_consts.py.
def managed_entry():
    d = {}
    d["short"] = 7
    d["this is a long string key"] = 35
    return d["short"] + d["this is a long string key"]

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
