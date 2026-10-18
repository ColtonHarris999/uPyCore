def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def acc():
    x = yield 1
    y = yield x
    yield y


g = acc()
print("next", next(g))
print("send", g.send(10))
print("send2", g.send(20))


def fresh():
    yield "started"


g = fresh()
show("early", lambda: g.send(1))
print("still", next(g))


def done():
    yield 1
    return 7


g = done()
print("y", next(g))
show("ret", lambda: next(g))
show("after", lambda: g.send(3))
