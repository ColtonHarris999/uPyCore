# Differential regression: run with tools/bulk_bench.py, including historical firmware.
# Exercise callback-free equality on independently allocated equal keys.
d = {i: i for i in range(32)}
for i in range(2, 32):
    del d[i]
s = 'key' + str(123)
big = (1 << 40) + 1
z = complex(2, 3)
d[s] = 10
d[big] = 11
d[z] = 12
d[b'abc'] = 13
src = {0.0: 20, complex(1, 0): 21, 'key123': 22,
       big + 0: 23, complex(2, 3): 24, bytes(bytearray(b'abc')): 25}
d.update(src)
assert len(d) == 6
assert [d[k] for k in (0, 1, s, big, z, b'abc')] == [20, 21, 22, 23, 24, 25]
a = set(d)
b = set(src)
assert len(a | b) == 6
assert len(a & b) == 6
assert len(a - b) == 0
assert len(a ^ b) == 0
print('extended keys ok')

# Hash callback order and observed collection sizes must match CA-disabled.
log = []
target = {}
class Key:
    def __init__(self, n):
        self.n = n
    def __hash__(self):
        log.append((self.n, len(target)))
        return self.n % 3
    def __eq__(self, other):
        return isinstance(other, Key) and self.n == other.n
for i in range(14):
    target[Key(i)] = i
assert len(target) == 14
for i in range(14):
    assert target[Key(i)] == i
print(log)
print('callback keys ok')

# Allocation/GC inside callbacks and nested aggregate hashes retain roots.
import gc
class GCKey(Key):
    def __hash__(self):
        gc.collect()
        log.append((self.n, len(target)))
        return -self.n if self.n & 1 else 0
log = []
target = {}
for i in range(6):
    target[(GCKey(i), i)] = i
for i in range(6):
    assert target[(GCKey(i), i)] == i
print(log)
assert len(target) == 6

# Exceptions during rebuilding must expose the same completed insertions.
class RaisingKey(Key):
    def __hash__(self):
        log.append((self.n, len(target)))
        if fail and self.n == 1:
            raise ValueError('hash failure')
        return 0
log = []
fail = False
target = {}
for i in range(4):
    target[RaisingKey(i)] = i
fail = True
try:
    for i in range(4, 12):
        target[RaisingKey(i)] = i
except ValueError:
    print('hash exception', len(target))
else:
    assert False
print(log)
print('callback gc and exception ok')
