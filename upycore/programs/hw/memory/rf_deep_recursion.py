# Ported from pycore pycore/programs/img_rf_deep_recursion.py.
# 500-frame recursion. Host CPython is the golden (returns 500).
# Requires MAX_CALL_DEPTH_CORE = 1024 and the RF ring + spill path.


def rec(n):
    if n == 0:
        return 0
    return rec(n - 1) + 1


def managed_entry():
    return rec(16)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
