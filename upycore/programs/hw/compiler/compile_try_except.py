# Ported from pycore pycore/programs/img_compile_try_except.py.
"""T4: compile() try/except TypeError → 7 (compiler_design.md §11.2).

Module names STOREd by the compiled program must be pre-bound so single-core
dict insert does not grow.
"""

SRC = """\
try:
    raise TypeError
except TypeError:
    x = 7
"""

x = None


def managed_entry():
    exec(compile(SRC, "<s>", "exec"))
    return x

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
