# list slice assignment from an exact list or tuple reads the right-hand
# side's items in place; aliases and other iterables still take a snapshot.
import gc


def show(tag, f):
    try:
        print(tag, f())
    except Exception as e:
        print(tag, type(e).__name__, e)


# Empty, equal, growing and shrinking replacements from list and tuple.
for rhs in ([], [7], [7, 8], [7, 8, 9, 10, 11], (), (7,), (7, 8), (7, 8, 9, 10, 11)):
    for a, b in ((0, 0), (0, 2), (1, 3), (2, 2), (3, 5), (5, 5), (4, 9), (-2, -1), (6, 2), (-9, 1)):
        x = [0, 1, 2, 3, 4, 5]
        x[a:b] = rhs
        print(a, b, type(rhs).__name__, len(rhs), x)

# Omitted bounds, deletes and extended slices.
x = list(range(8))
x[:] = (1, 2)
print(x)
x[len(x):] = [3, 4, 5]
print(x)
x[:0] = [0]
print(x)
del x[1:3]
print(x)


def assign(lst, a, b, v):
    lst[a:b] = v
    return lst


def assign_step(lst, v):
    lst[0:4:2] = v
    return lst


show('ext', lambda: assign_step(list(range(8)), [1, 2]))

# Self-assignment and alias of the destination.
x = [1, 2, 3, 4]
x[1:3] = x
print(x)
x = [1, 2, 3, 4]
x[:] = x
print(x)
x = [1, 2, 3, 4]
x[2:] = x
print(x)
x = [1, 2, 3, 4]
x[:1] = x
print(x)

# The RHS stays its own object: identity of elements, no shared storage.
m = [[1], [2]]
d = [0, 0, 0]
d[1:2] = m
print(d, d[1] is m[0], d[2] is m[1])
m[0].append(5)
m[1] = 'changed'
print(d, m)
d[0:1] = m
m.append('more')
print(d, m)

# A fresh reverse slice as RHS (the Fannkuch pattern).
p = [0, 1, 2, 3, 4, 5]
for k in range(1, 6):
    p[:k + 1] = p[k::-1]
    print(k, p)

# Tuple RHS growing past capacity, then GC.
y = [1]
for i in range(6):
    y[1:1] = tuple(range(i * 10, i * 10 + 7))
gc.collect()
print(len(y), y[:5], y[-3:])
y[2:40] = ()
gc.collect()
print(y)

# Shrinking leaves no stale references in the freed tail.
class Tracked:
    pass


z = [Tracked() for _ in range(8)]
z[2:8] = (1,)
gc.collect()
print(len(z), z[2])

# Bounds and the RHS come from calls; their order and effects are kept.
log = []


def at(v):
    log.append(v)
    return v


def rhs_of(v):
    log.append('rhs')
    return v


x = [0, 1, 2, 3, 4]
x[at(1):at(3)] = rhs_of([8, 9, 10])
print(x, log)


# A list or tuple RHS of the wrong kind is refused before any change.
class Sub(list):
    pass


x = [0, 1, 2]
y = Sub([5, 6])
print(type(y).__name__, len(y))


# Repeated equal-length replacements under GC pressure.
w = list(range(64))
src = list(range(100, 164))
for r in range(40):
    w[r:r + 16] = src[r:r + 16]
    junk = [i for i in range(20)]
gc.collect()
print(sum(w), w[:4], w[40:44], w[-4:])
