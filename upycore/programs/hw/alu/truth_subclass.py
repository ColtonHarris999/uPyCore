def show(x):
    print(bool(x), not x, True if x else False)
    if x:
        print(1)
    else:
        print(0)
    print("T" if (x or False) else "F")
    print("T" if (x and True) else "F")


class B(int):
    pass


class C(list):
    pass


class S(str):
    pass


class T(tuple):
    pass


class D(dict):
    pass


class Z(set):
    pass


class Y(bytearray):
    pass


show(B())
show(B(3))
show(C())
show(C([1]))
show(S())
show(S("a"))
show(T())
show(T((1,)))
show(D())
show(D({1: 2}))
show(Z())
show(Z({1}))
show(Y())
show(Y(b"a"))

d = {}
print(bool(d.keys()), bool(d.values()), bool(d.items()))
print(not d.keys())
if d.items():
    print("truthy")
else:
    print("falsy")
d[1] = 2
print(bool(d.keys()), bool(d.values()), bool(d.items()))
if d.keys():
    print("truthy")
else:
    print("falsy")

print(not memoryview(b""), not memoryview(b"ab"))
print(bool(memoryview(b"")), bool(memoryview(bytearray(b"xy"))))

import array

show(array.array("B"))
show(array.array("B", b"ab"))

try:
    hash({}.keys())
except TypeError:
    print("keys")
try:
    hash({}.items())
except TypeError:
    print("items")
print(type(hash({}.values())).__name__)
