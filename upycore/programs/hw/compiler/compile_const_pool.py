# Ported from pycore pycore/programs/img_compile_const_pool.py.
"""Def then non-small-int const plus empty if must compile (no TYPE/blit trap)."""

SRC = """\
def f():
    return 1
x = "hello"
y = 1000
if y:
    pass
"""


def managed_entry():
    ns = {}
    exec(compile(SRC, "<s>", "exec"), ns)
    if ns["f"]() == 1:
        if ns["x"] == "hello":
            if ns["y"] == 1000:
                return 7
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
