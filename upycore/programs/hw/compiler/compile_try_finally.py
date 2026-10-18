# Ported from pycore pycore/programs/img_compile_try_finally.py.
"""T4: compile() try/finally (compiler_design.md §11.2)."""

SRC = """\
x = 1
try:
    x = x + 1
finally:
    x = x + 10
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
