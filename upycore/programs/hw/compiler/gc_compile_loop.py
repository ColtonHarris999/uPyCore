import gc

# Ported from pycore pycore/programs/img_gc_compile_loop.py.
"""compile() the same closure several times and keep a few results."""


def managed_entry():
    src = "(lambda x: lambda: x)(7)"
    saved = []
    i = 0
    while i < 8:
        fn = eval(compile(src, "<gc-loop>", "eval"))
        if i == 0 or i == 3 or i == 5 or i == 7:
            saved.append(fn)
        gc.collect()
        i = i + 1
    total = 0
    for fn in saved:
        total = total + fn()
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
