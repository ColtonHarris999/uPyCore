# Ported from pycore pycore/programs/img_exec_globals_nested.py.
"""Two levels of exec(..., dict) with distinct namespaces.

"""

n1_v = 1
n2_v = 2


def managed_entry():
    n2 = {"n2_v": 10}
    n1 = {"n1_v": 20, "inner": inner, "n2": n2}
    exec(outer, n1)
    if n1_v != 1:
        return 0
    if n2_v != 2:
        return 0
    return n1["n1_v"] * 100 + n2["n2_v"]


inner = compile('n2_v = n2_v + 4', "<s>", 'exec')
outer = compile('n1_v = n1_v + 3\nexec(inner, n2)', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
