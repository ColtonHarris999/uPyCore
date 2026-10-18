# Ported from pycore pycore/programs/img_eval_str_long.py.
"""String-form eval() of a LONG_STR source (compiler_design.md §11.1).

``"1 + 2 + 3 + 4 + 5"`` is 17 UTF-8 bytes, so ``_bi_code_kind`` returns 8.
Expected: 15.
"""


def managed_entry():
    return eval("1 + 2 + 3 + 4 + 5")

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
