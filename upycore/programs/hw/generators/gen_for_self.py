def selfor():
    yield 1
    try:
        for v in me[0]:
            print("loop", v)
    except Exception as exc:
        print("caught", type(exc).__name__, exc)
    yield 3


me = []
me.append(selfor())
print("a", next(me[0]))
print("b", next(me[0]))
try:
    print("c", next(me[0]))
except StopIteration as exc:
    print("c", type(exc).__name__, exc, exc.value)
except Exception as exc:
    print("c", type(exc).__name__, exc)
