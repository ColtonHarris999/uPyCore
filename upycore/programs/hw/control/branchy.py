# Ported from pycore pycore/programs/img_branchy.py.
def managed_entry():
    n = 8
    total = 0
    while n:
        if n & 1:
            total += n
        else:
            total += 2
        n -= 1
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
