import gc

# Ported from pycore pycore/programs/img_gc_compile_syntaxerror.py.
"""Repeated compile() after a caught failure still compiles."""


def managed_entry():
    i = 0
    while i < 4:
        try:
            compile("import os", "<gc-bad>", "exec")
            rejected = False
        except SyntaxError:
            rejected = True
        if rejected:
            if compile("1", "<gc-ok>", "eval") is None:
                return 0
        else:
            compile("1 + 1", "<gc-ok>", "eval")
        gc.collect()
        i = i + 1
    return 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
