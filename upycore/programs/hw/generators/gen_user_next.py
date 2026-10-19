class Count:
    def __init__(self):
        self.i = 0

    def __iter__(self):
        return self

    def __next__(self):
        i = self.i
        print("call", i)
        if i == 2:
            raise StopIteration
        self.i = i + 1
        return i


print("for")
for v in Count():
    print("v", v)


def wrap():
    yield from Count()


print("from")
for v in wrap():
    print("w", v)
