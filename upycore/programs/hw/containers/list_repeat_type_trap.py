# Ported from pycore pycore/programs/img_list_repeat_type_trap.py.
"""STR * INT is sequence-repeat on STRACC: "ab" * 3 == "ababab".

``n`` is a local so CPython emits BINARY_OP rather than folding ``"ab" * 3``.
The old ALU TYPE-trapped; the accelerator matches CPython.
"""


def managed_entry():
    n = 3
    return len("ab" * n)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
