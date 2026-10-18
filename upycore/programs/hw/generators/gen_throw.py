def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def body():
    yield 1
    yield 2


def caught():
    try:
        yield 1
    except ValueError as exc:
        print("caught", type(exc).__name__, exc)
        yield 3


g = body()
next(g)
show("type", lambda: g.throw(ValueError))

g = body()
next(g)
show("inst", lambda: g.throw(ValueError("n")))

g = caught()
print("c0", next(g))
print("c1", g.throw(ValueError("n")))

g = body()
next(g)
show("third", lambda: g.throw(TypeError, ValueError("second"), "third"))

g = body()
next(g)
show("bad", lambda: g.throw("no"))
