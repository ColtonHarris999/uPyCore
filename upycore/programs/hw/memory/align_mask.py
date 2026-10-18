# Ported from pycore pycore/programs/img_align_mask.py.
# Alignment-style mask: flags & ~mask via UNARY_INVERT + BINARY_OP AND.
# 0xF & ~3 == 12.


def managed_entry():
    m = 3
    flags = 0xF
    return flags & ~m

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
