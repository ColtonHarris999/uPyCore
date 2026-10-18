# Ported from pycore pycore/programs/img_exec_code_nested.py.
"""A payload that itself calls exec() on a second payload.

"""

ne_a = 0
ne_b = 0


def managed_entry():
    exec(outer)
    return ne_a * 10 + ne_b


inner = compile('ne_b = ne_a + 1', "<s>", 'exec')
outer = compile('ne_a = 4\nexec(inner)', "<s>", 'exec')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
