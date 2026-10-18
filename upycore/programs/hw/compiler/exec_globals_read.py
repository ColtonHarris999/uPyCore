# Ported from pycore pycore/programs/img_exec_globals_read.py.
"""exec(code, dict) reads a pre-seeded key from the supplied namespace.

"""


def managed_entry():
    ns = {"gr_in": 40, "gr_out": 0}
    exec(payload, ns)
    return ns["gr_out"]


payload = compile('gr_out = gr_in + 1', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
