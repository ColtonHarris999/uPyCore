def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def five():
    yield 1
    return 5


g = five()
print("y", next(g))
show("value", lambda: next(g))

seen = []
for v in five():
    seen.append(v)
print("for", seen)

g = five()
next(g)
show("first", lambda: next(g))
show("again", lambda: next(g))

g = five()
print("default", next(g, "done"), next(g, "done"))
