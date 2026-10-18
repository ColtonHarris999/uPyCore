# Ported from pycore pycore/programs/img_try_stopiteration.py.
"""try/except StopIteration via table dispatch + CHECK_EXC_MATCH (§10 step 5)."""


def managed_entry():
    try:
        raise StopIteration
    except StopIteration:
        return 7

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
