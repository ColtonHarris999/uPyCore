# Ported from pycore pycore/programs/img_compile_lambda.py.
"""T5: compile() lambda call → 7."""


def managed_entry():
    return eval(compile("(lambda x: x + 1)(6)", "<s>", "eval"))

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
