def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def inner():
    yield "i"
    return 5


def mid():
    v = yield from inner()
    print("mid", v)
    return v + 1


def outer():
    v = yield from mid()
    print("outer", v)
    yield "o"


g = outer()
print("n0", next(g))
print("n1", next(g))
show("n2", lambda: next(g))

seen = []
for v in outer():
    seen.append(v)
print("for", seen)
