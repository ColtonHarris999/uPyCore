# Ported from pycore pycore/programs/img_eval_code_expr.py.
"""eval() an "eval"-mode code object: the expression value comes back.

"""

ev_a = 20


def managed_entry():
    return eval(expr)


expr = compile('ev_a * 2 + 1', "<s>", 'eval')

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
