def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def fin():
    try:
        yield 1
    finally:
        print("finally")


g = fin()
print("y", next(g))
show("close", g.close)


def ignore():
    try:
        yield 1
    except GeneratorExit:
        print("caught-exit")
        yield 2


g = ignore()
print("y2", next(g))
show("ignore", g.close)


def once():
    yield 1


g = once()
print("ran", list(g))
show("finished", g.close)


def early():
    print("body")
    yield 1


g = early()
show("fresh", g.close)
show("fresh-next", lambda: next(g))
