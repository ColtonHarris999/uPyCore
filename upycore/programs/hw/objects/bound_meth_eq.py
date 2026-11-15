class A:
    def f(s):
        pass

    def g(s):
        pass


a = A()
print(a.f == a.f, a.f is a.f, a.f != a.f)
print(a.f == a.g, a.f != a.g)
b = A()
print(a.f == b.f)
m1 = a.f
m2 = a.f
print(hash(m1) == hash(m2))
print(hash(a.f) == hash(a.g))
print([].append == [].append)
box = []
print(box.append == box.append, box.append != box.append)
print(hash(box.append) == hash(box.append))
print({m1: 1}[m2])
d = {}
keys = []
i = 0
while i < 32:
    keys.append(A().f)
    d[keys[i]] = i
    i += 1
print(d[keys[0]], d[keys[31]])
d[m1] = 7
print(d[m2])
