# Ported from pycore pycore/programs/img_list_concat_damerau.py.
"""damerau min([...]+[...]) shape after BINARY_SLICE tooling.

PyBGL ``damerau_levenshtein_distance_naive`` does
``1 + min([rec1, rec2, rec3] + ([rec4] if swap else []))``.
Use locals so CPython emits BUILD_LIST + BINARY_OP ADD, not LIST_EXTEND
of a const tuple.
"""


def managed_entry():
    take = 1
    a = 3
    b = 1
    c = 2
    extra = 4
    d = min([a, b, c] + ([extra] if take else []))
    return 111 + d

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
