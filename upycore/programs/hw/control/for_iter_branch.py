# Ported from pycore pycore/programs/img_for_iter_branch.py.
"""Branching loop body — COMPARE_OP + POP_JUMP_IF inside FOR_ITER.

Expected result: two values in (1, 5, 3) are > 2 → 2.
"""


def managed_entry():
    hits = 0
    for x in (1, 5, 3):
        if x > 2:
            hits += 1
    return hits

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
