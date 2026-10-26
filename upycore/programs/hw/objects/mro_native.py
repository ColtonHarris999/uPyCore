class C(list):
    pass


c = C([1, 2])
print(isinstance(c, list))
print(issubclass(C, list))
print(len(c))
print(c[0], c[-1])
print(c)
c[0] = 7
print(c)
print(c + [3])


class D(C):
    pass


d = D([4, 5])
print(isinstance(d, list))
print(issubclass(D, list))
print(len(d))
print(d[0], d[-1])
print(d)
e = D()
print(isinstance(e, list))
print(len(e))
print(e)
