# list.pop and list.insert. The core handles an exact list with a small-int
# or bool index (and spare capacity for insert); everything else takes the
# firmware method. Both must agree with the oracle.
import gc


def show(tag, f):
    try:
        print(tag, f())
    except Exception as e:
        print(tag, type(e).__name__, e)


# pop: default, first, middle, last, negative, out of range, empty.
for i in (None, 0, 1, 2, 3, 4, -1, -2, -5, 5, -6, True, False):
    x = [10, 11, 12, 13, 14]
    if i is None:
        show('pop()', lambda: (x.pop(), x))
    else:
        show('pop(%r)' % (i,), lambda: (x.pop(i), x))
show('pop-empty', lambda: [].pop())
show('pop-empty0', lambda: [].pop(0))
show('pop-wide', lambda: [1, 2].pop(2 ** 40))
show('pop-float', lambda: [1, 2].pop(1.0))
show('pop-args', lambda: [1, 2].pop(0, 1))

# insert: both ends, clamping, every position. (MicroPython reads a bool
# insert position as a raw object word, so bools are left out.)
for i in (0, 1, 3, 5, 6, 100, -1, -5, -6, -100):
    x = [10, 11, 12, 13, 14]
    x.insert(i, 'v')
    print('insert(%r)' % (i,), x)
for n in range(6):
    for i in range(-n - 1, n + 2):
        x = list(range(n))
        x.insert(i, -1)
        print(n, i, x)
show('ins-args', lambda: [1, 2].insert(0))

# Capacity boundaries: grow past the allocation one insert at a time.
x = []
for i in range(40):
    x.insert(i // 2, i)
print(len(x), x)
while x:
    x.pop(len(x) // 3)
print(x)

# Identity and aliasing; removed slots do not keep the object alive.
a = [1]
b = [2]
x = [a, b, a]
y = x
p = x.pop(1)
print(p is b, y is x, y, x[1] is a)
x.insert(0, b)
print(x[0] is b, y)


class Tracked:
    pass


z = [Tracked() for _ in range(6)]
for _ in range(6):
    z.pop(0)
gc.collect()
print(len(z), z)

# Repeated pop/insert pairs, the Fannkuch pattern, under GC pressure.
perm = list(range(6))
count = [0] * 6
out = []
for step in range(60):
    r = 1 + step % 5
    p0 = perm.pop(0)
    perm.insert(r, p0)
    out.append(perm[0] * 10 + perm[-1])
    if step % 7 == 0:
        junk = [list(range(8)) for _ in range(4)]
gc.collect()
print(perm, sum(out), out[:10])

# Long tails.
w = list(range(300))
print(w.pop(0), w.pop(150), w.pop(-2), len(w), w[:3], w[148:151], w[-3:])
w.insert(0, 'a')
w.insert(150, 'b')
w.insert(-1, 'c')
print(len(w), w[:3], w[149:152], w[-3:])
v = w.pop(0)
w.insert(0, v)
print(w[:2], sum(i for i in w if isinstance(i, int)))


# Subclasses: overrides win; plain subclasses keep list behavior.
class L(list):
    pass


class Loud(list):
    def pop(self, *a):
        print('Loud.pop', a)
        return 'mine'

    def insert(self, i, v):
        print('Loud.insert', i, v)


s = L([1, 2, 3])
print(s.pop(), s.pop(0), s)
s.insert(0, 9)
print(s)
q = Loud([1, 2])
print(q.pop(), q.pop(0))
q.insert(1, 2)
print(list(q))

# Bound methods.
x = [1, 2, 3]
f = x.pop
g = x.insert
g(0, 0)
print(f(), f(0), x)
print(list.pop([7, 8]), list.insert([7], 0, 6))
