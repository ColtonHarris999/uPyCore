# Retained spare capacity makes repeated merges eligible without allocation.
d = {i: i for i in range(32)}
for i in range(10, 32):
    del d[i]
s = set(range(32))
for i in range(10, 32):
    s.remove(i)
other = {i: -i for i in range(5, 15)}
t = set(range(5, 15))
for iteration in range(4):
    d.update(other)
    s.update(t)
    s.difference_update(t)
    s.update(t)
    s.intersection_update(t)
print(len(d), d[7], len(s), 7 in s, 999 in s)
