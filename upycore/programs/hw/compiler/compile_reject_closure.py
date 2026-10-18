# Ported from pycore pycore/programs/img_compile_reject_closure.py.
"""§11.4: nested load of an enclosing local compiles and runs.

compile()+exec of a nested function that reads an outer local returns 1.
"""

SRC = """\
def outer():
    x = 1
    def inner():
        return x
    return inner()
"""


def managed_entry():
    ns = {}
    exec(compile(SRC, "<s>", "exec"), ns)
    return ns["outer"]()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
