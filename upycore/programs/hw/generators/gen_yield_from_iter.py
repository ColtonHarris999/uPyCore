def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def from_list():
    yield from [1, 2, 3]


print("list", list(from_list()))


def send_list():
    yield from [1, 2, 3]


g = send_list()
print("y", next(g))
show("send", lambda: g.send(9))
