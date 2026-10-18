# Ported from pycore pycore/programs/img_dict_merge.py.
"""DICT_MERGE non-empty destination via CALL_FUNCTION_EX **kwargs.

`f(**{...}, **{...})` emits BUILD_MAP 0 + two DICT_MERGE. The first merges into
the empty accumulator (pycore alias fast path); the second has a non-empty dest
and routes to the excore DICT_MERGE handler, which builds the combined kwargs
dict C (needs EXCORE_EN=1 / two-core). The callee binds the merged string keys
to positional parameters.
"""


def f(a, b, c):
    return a + b * 10 + c * 100


def managed_entry():
    return f(**{"a": 1, "b": 2}, **{"c": 3})

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
