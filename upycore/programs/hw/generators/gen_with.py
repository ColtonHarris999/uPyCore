import gc


def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


class Gate:
    def __enter__(self):
        print("enter")
        return "v"

    def __exit__(self, et, ev, tb):
        print("exit", None if et is None else et.__name__)
        return False


def abandoned():
    with Gate():
        yield 1
        print("after")


def closed():
    with Gate():
        yield 1
        print("after")


g = abandoned()
print("a", next(g))
g = None
gc.collect()
print("dropped")

g = closed()
print("b", next(g))
show("close", g.close)
