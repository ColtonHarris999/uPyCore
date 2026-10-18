def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


async def child(n):
    yield n
    return n + 1


async def parent():
    v = await child(2)
    return v + 3


g = parent()
print("send", g.send(None))
show("next", lambda: next(g))


class Count:
    def __init__(self, n):
        self.i = 0
        self.n = n

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self.i >= self.n:
            raise StopAsyncIteration
        self.i += 1
        return self.i


async def walk():
    async for n in Count(2):
        print("af", n)


g = walk()
show("af-drive", lambda: next(g))
