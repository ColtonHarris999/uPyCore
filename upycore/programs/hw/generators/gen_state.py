def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def local():
    n = 0
    n += 1
    yield n
    n += 1
    yield n


g = local()
print("local", next(g), next(g))


def outer(k):
    n = k

    def inner():
        nonlocal n
        n += 1
        yield n
        n += 10
        yield n

    return inner()


g = outer(5)
print("cell", next(g), next(g))


def fin():
    try:
        yield 1
        return 4
    finally:
        print("finally")


g = fin()
print("y", next(g))
show("ret", lambda: next(g))


def pep():
    yield 1
    raise StopIteration


g = pep()
print("pep-y", next(g))
show("pep", lambda: next(g))
show("pep-after", lambda: next(g))
