def boom():
    yield 1
    raise ValueError("boom")


g = boom()
next(g)
next(g)
