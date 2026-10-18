# Ported from pycore pycore/programs/img_compile_str_slice.py.
"""T4: compile() string slice (compiler_design.md §11.2)."""


def managed_entry():
    s = eval(compile("'abcdef'[1:4]", "<s>", "eval"))
    if s == "bcd":
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
