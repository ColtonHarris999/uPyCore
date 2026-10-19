def inner():
    x = yield 0
    print("got", x)
    yield x


def outer():
    yield from inner()


g = outer()
print("n", next(g))
print("s", g.send(1))
