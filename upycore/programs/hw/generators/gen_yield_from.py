def sub():
    yield 1
    yield 2
    return 5


def outer():
    v = yield from sub()
    print("returned", v)
    yield v


print("vals", list(outer()))
