# Ported from pycore pycore/programs/img_compile_decorator.py.
"""T5: identity decorator around a def that returns 7."""

SRC = """\
def d(fn):
    return fn
@d
def f():
    return 7
"""


def managed_entry():
    ns = {}
    exec(compile(SRC, "<s>", "exec"), ns)
    return ns["f"]()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
