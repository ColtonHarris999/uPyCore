def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def child():
    yield 1
    raise ValueError("boom")


def parent():
    try:
        v = yield from child()
        print("after", v)
    finally:
        print("fin")


g = parent()
print("y", next(g))
show("n", lambda: next(g))
