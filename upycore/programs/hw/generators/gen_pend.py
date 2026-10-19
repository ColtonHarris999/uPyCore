def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def ticks():
    yield 1
    yield 2


g = ticks()
print("y", next(g))
print("prev", g.pend_throw(ValueError("p")))
show("fired", lambda: next(g))

g = ticks()
print("drained", list(g))
print("fin-prev", g.pend_throw(ValueError("later")))
show("fin-next", lambda: next(g))


def selfnext():
    yield 1
    next(box[0])
    yield 2


box = []
box.append(selfnext())
print("self-y", next(box[0]))
show("self", lambda: next(box[0]))


def fresh():
    yield "ran"


g = fresh()
print("early-prev", g.pend_throw(ValueError("kept")))
show("early-send", lambda: g.send(1))
show("early-next", lambda: next(g))
