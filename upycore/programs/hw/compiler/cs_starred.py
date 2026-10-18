# Ported from pycore pycore/programs/compile_suite/cs_starred.py.
# Compile suite: `*` / `**` unpacking. Every form here compiles to
# CALL_FUNCTION_EX, DICT_MERGE, LIST_EXTEND, SET_UPDATE, DICT_UPDATE,
# UNPACK_EX or CALL_INTRINSIC_1 (list-to-tuple), the way CPython 3.14 emits.


def count(*args, **kwargs):
    return len(args) * 10 + len(kwargs)


def total(a, b=2, *rest, c=3, **extra):
    n = a + b + c
    for x in rest:
        n += x
    for k in extra:
        n += extra[k]
    return n


xs = [1, 2, 3]
kw = {"p": 4, "q": 5}
print("call *xs", count(*xs))
print("call mixed", count(0, *xs, 9))
print("call **kw", count(**kw))
print("call both", count(1, *xs, r=6, **kw))
print("kw then **", count(z=1, **kw))
print("pos + **", count(7, **kw))
print("total", total(*[10, 20, 30, 40], **{"c": 1, "d": 2}))

# Starred displays (* in a list, tuple, set, or dict literal) are not in
# this MicroPython. The same objects are built with concatenation and update.
a = [1, 2]
b = (3, 4)
lst = a + [5] + list(b)
print("list", len(lst), lst[0], lst[4])
tup = tuple(a)
print("tuple", len(tup), tup[1])
tup2 = (0,) + b
print("tuple2", tup2[0] + tup2[2])
st = set(a)
st.add(9)
st.update(b)
print("set", len(st), 9 in st)
d1 = {"x": 1}
d2 = {"y": 2}
d = {}
d.update(d1)
d["z"] = 3
d.update(d2)
print("dict", len(d), d["x"] + d["y"] + d["z"])

vals = [1, 2, 3, 4, 5]
h, *t = vals
print("head", h, len(t))
f, *mid, g = vals
print("mid", f, len(mid), g)
*init, last = vals
print("init", len(init), last)
for first, *more in [[1, 2, 3], [4]]:
    print("for", first, len(more))
