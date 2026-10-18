# Ported from pycore pycore/programs/img_compile_assert.py.
"""T5: compile() assert that holds, then 1."""


def managed_entry():
    exec(compile("assert 1\n", "<s>", "exec"))
    return 1

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
