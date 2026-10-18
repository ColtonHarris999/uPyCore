# Ported from pycore pycore/programs/img_exec_code_basic.py.
"""exec() a precompiled module-mode code object; its STORE_NAME hits globals.

"""

ex_x = 0
ex_y = 0


def managed_entry():
    exec(snippet)
    return ex_x + ex_y


snippet = compile('ex_x = 1 + 2\nex_y = ex_x * 10', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
