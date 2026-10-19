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
seen = []
for v in g:
    seen.append(v)
print("for", seen)
show("after", lambda: next(g))
