# Ported from pycore pycore/programs/img_compile_reject_import.py.
"""A4: import is a compiler SyntaxError (compiler_design.md I).

The parser rejects unsupported statement keywords rather than emitting an
illegal opcode. Returns 1 when ``compile("import os", …)`` raises.
"""


def managed_entry():
    try:
        compile("import os", "<s>", "exec")
    except SyntaxError:
        return 1
    return 0

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
