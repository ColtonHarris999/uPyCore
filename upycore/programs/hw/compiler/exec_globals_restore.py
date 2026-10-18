# Ported from pycore pycore/programs/img_exec_globals_restore.py.
"""After exec(code, dict) returns, module STORE/LOAD hit module globals again.

The payload also calls a helper stored in the namespace so the save/restore
covers a nested CALL while the override is live (Plan 1 P4 regression).

"""

rs_x = 1


def helper(x):
    return x + 50


def after():
    return rs_x


def managed_entry():
    ns = {"rs_x": 10, "helper": helper}
    exec(payload, ns)
    if rs_x != 1:
        return 0
    return after() * 1000 + ns["rs_x"]


payload = compile('rs_x = helper(rs_x)', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
