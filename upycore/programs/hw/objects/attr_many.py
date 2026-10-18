# Ported from pycore pycore/programs/img_attr_many.py.
"""Eight instance attributes — forces PY_TRAP_DICT_GROW (slots=4, load≥2/3).

Requires the two-core / EXCORE_EN=1 path. Return sum of all attrs.

"""


def managed_entry():
    o.a = 1
    o.b = 2
    o.c = 3
    o.d = 4
    o.e = 5
    o.f = 6
    o.g = 7
    o.h = 8
    return o.a + o.b + o.c + o.d + o.e + o.f + o.g + o.h


class _o:
    pass
o = _o()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
