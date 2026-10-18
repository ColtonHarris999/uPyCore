# Ported from pycore pycore/programs/img_try_syntaxerror.py.
"""raise SyntaxError caught by an exact-match except handler.

CHECK_EXC_MATCH is exact-handle in v1, so the seeded leaf OBK_TYPE for
SyntaxError must be the same handle the raise site loaded.
"""


def managed_entry():
    total = 0
    try:
        raise SyntaxError
    except SyntaxError:
        total += 1
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
