def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def sub_throw():
    try:
        yield 1
    except ValueError as exc:
        print("sub", type(exc).__name__, exc)
        yield 2
        return 7


def outer_throw():
    v = yield from sub_throw()
    yield v


g = outer_throw()
print("t0", next(g))
print("t1", g.throw(ValueError("n")))
print("t2", next(g))


def sub_fin():
    try:
        yield 1
    finally:
        print("sub-fin")


def outer_fin():
    try:
        yield from sub_fin()
    finally:
        print("outer-fin")


g = outer_fin()
print("c0", next(g))
show("c1", g.close)


def sub_yield():
    try:
        yield 1
    except GeneratorExit:
        print("sub-yield")
        yield 2


def outer_yield():
    yield from sub_yield()


g = outer_yield()
print("i0", next(g))
show("i1", g.close)


def sub_ret():
    try:
        yield 1
    except GeneratorExit:
        print("sub-return")


def outer_ret():
    try:
        v = yield from sub_ret()
        print("after", v)
    except GeneratorExit:
        print("outer-exit")


g = outer_ret()
print("r0", next(g))
show("r1", g.close)
