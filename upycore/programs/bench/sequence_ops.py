for n in (0, 1, 2, 3, 16, 33, 64):
    a = [i % 7 for i in range(n)]
    t = tuple(a)
    expected = list(a)
    for value in (0, 3, 6, 9):
        count = sum(1 for x in expected if x == value)
        assert a.count(value) == count
        assert t.count(value) == count
        assert (value in a) == (count != 0)
        assert (value in t) == (count != 0)
        for start, stop in ((0, n), (-10, -1), (3, 12), (n, n + 3)):
            indices = list(range(n))[start:stop]
            wanted = -1
            for i in indices:
                if expected[i] == value:
                    wanted = i
                    break
            for seq in (a, t):
                try:
                    got = seq.index(value, start, stop)
                except ValueError:
                    got = -1
                assert got == wanted
    a.reverse()
    assert a == expected[::-1]
    a.reverse()
    assert a == expected
# Mixed tagged elements must retain their identities through swaps.
x = object()
a = [None, True, 'abc', b'xyz', 1 << 40, (1, 2), x]
b = a[:]
a.reverse()
for i in range(len(a)):
    assert a[i] is b[len(b) - 1 - i]
# Callback-bearing scans stay in firmware, including a callback that mutates.
log = []
class K:
    def __init__(self, n): self.n = n
    def __eq__(self, other):
        log.append(self.n)
        return self.n == other.n
seq = [K(0), K(1), K(0)]
assert seq.count(K(0)) == 2
assert seq.index(K(1)) == 1
assert K(1) in seq
print(log)
# Float/complex scans deliberately retain the original comparison semantics.
nan = float('nan')
seq = [nan, 0.0, complex(1, 0)]
print(seq.count(nan), seq.count(0), seq.index(1), nan in seq)
print('sequence ops ok')
