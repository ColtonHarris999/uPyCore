# Ported from pycore pycore/programs/img_pop_jump_if_none.py.
# Exercises POP_JUMP_IF_NONE / POP_JUMP_IF_NOT_NONE via is None / is not None.
#
# Bit-score: each true condition adds a power of two.  Host golden is 7
# (1+2+4).  The skipped +8 branch proves NOT_NONE polarity on a non-None INT.


def managed_entry():
    n = None
    x = 1
    lst = []
    out = 0
    if n is None:
        out += 1
    if x is not None:
        out += 2
    if lst is not None:
        out += 4
    if x is None:
        out += 8
    return out

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
