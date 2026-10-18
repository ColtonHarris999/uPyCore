# Ported from pycore pycore/programs/img_compile_raise.py.
"""T4: compile() raise TypeError is caught (compiler_design.md §11.2)."""

SRC = """\
try:
    raise TypeError
except TypeError as e:
    x = 7
"""

x = None
e = None


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
