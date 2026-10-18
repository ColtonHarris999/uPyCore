# Ported from pycore pycore/programs/img_exec_code_returns_none.py.
"""exec() returns None regardless of what the payload's body evaluates to.

"""

rn_v = 0


def managed_entry():
    out = exec(snippet)
    total = rn_v
    if out is None:
        total += 100
    return total


snippet = compile('rn_v = 7', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
