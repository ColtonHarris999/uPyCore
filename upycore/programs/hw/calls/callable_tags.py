def make(offset):
    def add(x, y=3, *rest, **kwargs):
        return offset + x + y + len(rest) + kwargs.get('extra', 0)
    return add


def values():
    yield 7


class Sized:
    def __len__(self):
        return 5

    @staticmethod
    def scale(x):
        return x * 2

    @classmethod
    def size(cls):
        return len(cls())

    @property
    def amount(self):
        return 9


f = make(10)
assert len is len and f is f and f is not make(10)
assert callable(f) and callable(len)
assert isinstance(f, type(f)) and isinstance(len, type(len))
assert hash(f) == hash(f) and hash(len) == hash(len)
assert id(f) == id(f) and id(len) == id(len)
table = {f: 1, len: 2}
assert table[f] == 1 and table[len] == 2 and f in {f, len}
assert f(1) == 14 and f(1, *[2, 3], **{'extra': 4}) == 18
assert next(values()) == 7
obj = Sized()
bound = obj.__len__
seq = []
append = seq.append
get = table.get
append(bound())
assert seq == [5] and get(f) == 1
assert obj.scale(3) == 6 and obj.size() == 5 and obj.amount == 9
assert list(map(len, ('a', 'bb'))) == [1, 2]
assert sorted(('bb', 'a'), key=len) == ['a', 'bb']
assert list(filter(len, ('', 'a'))) == ['a']
assert len(obj) == 5
try:
    len()
except TypeError as exc:
    assert str(exc)
else:
    raise AssertionError('len accepted zero arguments')
print('callable tags ok')
