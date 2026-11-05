# List slices with a step other than 1 gather the items in the core
# (_wcopy_step). Every short-list combination must match the oracle.
import gc

bounds = (None, -9, -2, -1, 0, 1, 3, 9)
total = 0
lines = 0
for n in range(8):
    x = list(range(n))
    for step in (-3, -1, 2):
        for a in bounds:
            for b in bounds:
                r = x[a:b:step]
                total = total * 31 + len(r) * 7 + sum(r) & 0xFFFFFF
                if n in (0, 1, 5, 7) and step in (-1, 2) and a in (None, -1, 1) and b in (None, 0, -9):
                    print(n, a, b, step, r)
                    lines += 1
print('checksum', total, lines)

# Zero step.
try:
    [1, 2, 3][::0]
except ValueError as e:
    print('ValueError', e)

# Mixed tags and element identity; the result is an independent list.
o = ('o',)
inner = [1]
src = [0, None, 1.25, True, 'x', (), inner, o, 2 ** 40, -7, b'b', {1: 2}]
r = src[::-1]
print(len(r), r[0] is src[-1], r[5] is inner, r[4] is o)
print([type(v).__name__ for v in r])
print(src[::-2][:4], src[1::3], src[-2::-4])
r[0] = 'changed'
inner.append(2)
print(src[-1], r[5], src[6])

# The Fannkuch reverse-prefix pattern, and long lists under GC.
perm = list(range(9))
for k in range(1, 9):
    perm[:k + 1] = perm[k::-1]
print(perm)
big = list(range(1000))
rev = big[::-1]
gc.collect()
print(len(rev), rev[:3], rev[-3:], sum(big[::7]), big[999:0:-250], big[-1:-1000:-333])

# Tuples, strings and bytes keep their existing step support.
for s in ((1, 2, 3, 4), 'abcd', b'abcd', bytearray(b'abcd'), range(6)):
    try:
        print(s[::-1], s[::2])
    except Exception as e:
        print(type(e).__name__, e)
