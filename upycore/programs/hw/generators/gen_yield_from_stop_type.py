# Throw the StopIteration class through yield from a list.
# The oracle raises RuntimeError. The device completes the delegation.
# Not a manifest entry. See planning/generators_review.md.


def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


class MyStop(StopIteration):
    pass


def from_list():
    yield from [1, 2]
    print("after")
    return 3


g = from_list()
print("y", next(g))
show("throw", lambda: g.throw(StopIteration))
show("next", lambda: next(g))

g = from_list()
print("y2", next(g))
show("sub", lambda: g.throw(MyStop))
show("next2", lambda: next(g))
