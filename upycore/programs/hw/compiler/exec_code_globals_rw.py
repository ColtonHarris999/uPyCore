# Ported from pycore pycore/programs/img_exec_code_globals_rw.py.
"""The payload reads an existing global and writes a new one.

"""

rw_in = 30
rw_out = 0


def managed_entry():
    exec(snippet)
    return rw_out


snippet = compile('rw_out = rw_in + 5', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
