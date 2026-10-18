# Ported from pycore pycore/programs/img_compile_eval_expr.py.
"""A1: eval(compile("1 + 2")) == 3 (compiler_design.md step I).

Public ROM ``compile()`` stores source on ``_PYC_G``, runs T1 codegen, and
returns a code object. ``eval`` calls it (``eval.py``: ``code()``).
"""


def managed_entry():
    return eval(compile("1 + 2", "<s>", "eval"))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
