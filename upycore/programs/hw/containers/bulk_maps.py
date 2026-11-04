import gc


def roomy_set():
    s = set(range(32))
    for k in range(10, 32):
        s.remove(k)
    return s


def roomy_dict():
    d = {k: k + 100 for k in range(32)}
    for k in range(10, 32):
        del d[k]
    return d


for repeat in range(1):
    a = roomy_dict()
    b = {k: -k for k in range(5, 25)}
    a.update(b)
    b[7] = 999
    gc.collect()
    assert len(a) == 25 and a[7] == -7 and a[0] == 100
    for op in range(4):
        a = roomy_set()
        b = set(range(5, 25))
        if op == 0:
            a.update(b)
            expected = set(range(25))
        elif op == 1:
            a.difference_update(b)
            expected = set(range(5))
        elif op == 2:
            a.intersection_update(b)
            expected = set(range(5, 10))
        else:
            a.symmetric_difference_update(b)
            expected = set(range(5)) | set(range(10, 25))
        b.add(999)
        gc.collect()
        assert a == expected
        for k in range(-20, 0):
            a.add(k)
        assert all(k in a for k in range(-20, 0))

# Equality across immediate tag encodings.
a = roomy_dict()
a.update({True: 77, False: 88, None: 99})
assert a[1] == 77 and a[0] == 88 and a[None] == 99
# Non-immediate equality must stay in software.
a.update({1.0: 111, 'name': 222, (1, 2): 333})
assert a[True] == 111 and a['name'] == 222 and a[(1, 2)] == 333

class Key:
    calls = 0
    def __init__(self, n):
        self.n = n
    def __hash__(self):
        Key.calls += 1
        return 7
    def __eq__(self, other):
        return isinstance(other, Key) and self.n == other.n

x, y = Key(1), Key(1)
a = roomy_dict()
a[x] = 1
a.update({y: 2})
assert a[x] == 2 and Key.calls > 0
# Aliases and empty tables use the ordinary semantic path.
s = set(range(12))
s.update(s)
assert len(s) == 12
s.difference_update(s)
assert len(s) == 0
s = set(range(12))
s.symmetric_difference_update(s.copy())
assert not s
print('bulk maps ok')
