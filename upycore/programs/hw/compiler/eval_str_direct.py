# Ported from pycore pycore/programs/img_eval_str_direct.py.
"""String-form eval() compiles SHORT_STR source (compiler_design.md §11.1).

``eval("1 + 2")`` probes the tag, runs ROM ``compile(..., "eval")``, and
calls the result. Expected: 3.
"""


def managed_entry():
    return eval("1 + 2")

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
