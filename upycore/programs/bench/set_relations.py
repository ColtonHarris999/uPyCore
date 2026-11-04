a = set(range(24))
b = set(range(32))
c = set(range(40, 56))
for i in range(4):
    assert a.issubset(b)
    assert not b.issubset(a)
    assert b.issuperset(a)
    assert a.isdisjoint(c)
    assert not a.isdisjoint(b)
    assert a.issubset(a)
    assert not a.isdisjoint(a)
    assert set().issubset(a)
    assert set().isdisjoint(a)
    assert a.isdisjoint(set())
    assert not a.issubset(set())
    assert frozenset(a).issubset(frozenset(b))
    assert frozenset(a).isdisjoint(frozenset(c))
# Numeric equality, tombstones, mixed immutable scalar types.
a = {0, 1, 'key123', (1 << 40) + 1, complex(2, 3), b'abc'}
b = {0.0, complex(1, 0), 'key' + str(123), (1 << 40) + 1, complex(2, 3), bytes(bytearray(b'abc'))}
assert a.issubset(b) and b.issubset(a)
assert not a.isdisjoint(b)
for k in range(32):
    b.add(k)
for k in range(2, 32):
    b.remove(k)
assert a.issubset(b)
# Preserve callback count/order on fallback.
log = []
class K:
    def __init__(self, n): self.n = n
    def __hash__(self):
        log.append(('h', self.n))
        return 0
    def __eq__(self, other):
        log.append(('e', self.n, other.n))
        return self.n == other.n
a = {K(1), K(2)}
b = {K(1), K(2), K(3)}
log = []
assert a.issubset(b)
assert not a.isdisjoint(b)
print(log)
print('set relations ok')
