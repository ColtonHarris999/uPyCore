def ticks():
    yield 1
    yield 2


g = ticks()
print("prev", g.pend_throw(ValueError("p")))
try:
    for v in g:
        print("v", v)
    print("done")
except Exception as exc:
    print(type(exc).__name__, exc)
