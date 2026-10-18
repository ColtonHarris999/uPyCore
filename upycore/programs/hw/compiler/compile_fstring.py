# Ported from pycore pycore/programs/img_compile_fstring.py.
"""T5: simple f-string FORMAT_SIMPLE + BUILD_STRING → 1."""


def managed_entry():
    if eval(compile('f"a{1}b"', "<s>", "eval")) == "a1b":
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
