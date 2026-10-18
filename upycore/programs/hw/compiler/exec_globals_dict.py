# Ported from pycore pycore/programs/img_exec_globals_dict.py.
"""exec(code, dict) writes into the dict; module globals stay put.

"""

gd_x = 1


def managed_entry():
    ns = {"gd_x": 0}
    exec(payload, ns)
    return gd_x * 100 + ns["gd_x"]


payload = compile('gd_x = 77', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
