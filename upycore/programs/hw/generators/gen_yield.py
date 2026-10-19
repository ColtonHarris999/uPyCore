def seq():
    yield 1
    yield 2
    yield 3


print("for")
for v in seq():
    print("for", v)

a = seq()
b = seq()
print("live", next(a), next(b), next(a), next(b))


def pack(a, b=4, *args, c):
    yield a
    yield b
    yield args
    yield c


g = pack(1, c=9)
print("default", next(g), next(g), next(g), next(g))
g = pack(1, 2, 3, 4, c=5)
print("sig", next(g), next(g), next(g), next(g))

print("genexp")
for v in (n * n for n in range(3)):
    print("genexp", v)
