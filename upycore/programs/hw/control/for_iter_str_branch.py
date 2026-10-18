# Ported from pycore pycore/programs/img_for_iter_str_branch.py.
"""String loop values remain usable by a branching loop body."""


def managed_entry():
    score = 0
    for c in "135":
        if c == "1":
            score += 100
        if c == "3":
            score += 10
        if c == "5":
            score += 1
    return score

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
