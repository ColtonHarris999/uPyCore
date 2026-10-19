def boom():
    yield 1
    raise StopIteration


def run(label, g):
    try:
        for v in g:
            print(label, v)
        print(label, "done")
    except Exception as exc:
        print(label, type(exc).__name__, exc)


run("body", boom())


def immediate():
    raise StopIteration
    yield 0


run("imm", immediate())
