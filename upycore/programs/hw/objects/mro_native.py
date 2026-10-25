class C(list):
    pass


c = C([1, 2])
print(isinstance(c, list))
print(issubclass(C, list))
print(len(c))
print(c[0], c[-1])
c.append(9)
print(c)
print(c[2])


class D(C):
    pass


d = D()
print(isinstance(d, list))
print(issubclass(D, list))
d.append(4)
print(len(d))
print(d[0])
print(d)
