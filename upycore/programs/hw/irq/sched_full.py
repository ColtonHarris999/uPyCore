# Eight schedule() calls fill the ring with no jump in between; the ninth
# raises. Then each jump runs one callback.
import micropython

out = []


def cb(n):
    out.append(n)


s = micropython.schedule
s(cb, 0)
s(cb, 1)
s(cb, 2)
s(cb, 3)
s(cb, 4)
s(cb, 5)
s(cb, 6)
s(cb, 7)
try:
    s(cb, 8)
except RuntimeError as e:
    print('RuntimeError:', e)
print(len(out))
n = 0
while n < 10:
    n += 1
print(out)
s(cb, 9)
s(cb, 10)
