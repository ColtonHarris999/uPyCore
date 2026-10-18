# Ported from pycore pycore/programs/img_try_stopiteration_nested.py.
"""Nested try/except StopIteration exercises the dmem exc-info stack."""


def managed_entry():
    try:
        try:
            raise StopIteration
        except StopIteration:
            raise StopIteration
    except StopIteration:
        return 11

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
