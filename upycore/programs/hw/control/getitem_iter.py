class G:
    def __getitem__(self, i):
        if i == 2:
            raise IndexError
        return i


out = []
for n in G():
    out.append(n)
print(out)


class Bad:
    def __getitem__(self, i):
        raise ValueError("bad")


try:
    for n in Bad():
        print(n)
except ValueError as e:
    print(type(e).__name__)
    print(e.args)


class HasIter:
    def __iter__(self):
        return iter((5, 6))

    def __getitem__(self, i):
        raise RuntimeError("fallback")


out = []
for n in HasIter():
    out.append(n)
print(out)


class Stop:
    def __getitem__(self, i):
        if i == 1:
            raise StopIteration
        return i


out = []
for n in Stop():
    out.append(n)
print(out)
