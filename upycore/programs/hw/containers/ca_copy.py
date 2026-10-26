# Bulk copies run on the container accelerator while the core moves on.
# Each check reads or writes a copy's words right after it is shipped, so
# the scoreboard has to hold the access until those words have landed.
import gc


def check(name, got, want):
    print(name, "ok" if got == want else "BAD %r != %r" % (got, want))


a = list(range(1000))

# Read the last destination word at once: the copy is still running.
b = a + a
check("concat tail", b[-1], 999)
check("concat mid", b[1000], 0)
check("concat len", len(b), 2000)

# Store to a source word right after the ship: it must not reach the copy.
c = a[:]
a[999] = -1
check("slice src store", c[999], 999)
a[999] = 999

# Store to a destination word right after the ship: the copy must not undo it.
d = a[:]
d[998] = "x"
check("slice dst store", d[998], "x")
check("slice dst neighbour", d[997], 997)

t = tuple(a)
check("tuple of list", t[-1], 999)
e = list(t)
check("list of tuple", (e[0], e[-1], len(e)), (0, 999, 1000))

# Overlapping shifts inside one item array, both directions.
f = list(range(10))
f.insert(0, "first")
check("insert head", f[:4], ["first", 0, 1, 2])
f.insert(5, "mid")
check("insert mid", f, ["first", 0, 1, 2, 3, "mid", 4, 5, 6, 7, 8, 9])
check("pop head", f.pop(0), "first")
check("after pop", f, [0, 1, 2, 3, "mid", 4, 5, 6, 7, 8, 9])
del f[4]
check("del mid", f, list(range(10)))
f.remove(0)
check("remove", f, list(range(1, 10)))

# extend with itself and with a tuple; a list that grows mid-copy.
g = [1, 2, 3]
g.extend(g)
check("extend self", g, [1, 2, 3, 1, 2, 3])
g += (7, 8)
check("extend tuple", g, [1, 2, 3, 1, 2, 3, 7, 8])
h = []
for i in range(300):
    h.append(i)
    if i % 64 == 0:
        check("grow early %d" % i, h[0], 0)
check("grow end", (h[-1], len(h), sum(h)), (299, 300, 44850))

# Slice assignment: grow, shrink, and a stop below the start.
s = list(range(8))
s[2:4] = ["a", "b", "c", "d"]
check("setslice grow", s, [0, 1, "a", "b", "c", "d", 4, 5, 6, 7])
s[1:7] = []
check("setslice shrink", s, [0, 5, 6, 7])
s[3:1] = [9]
check("setslice clamp", s, [0, 5, 6, 9, 7])
del s[0:2]
check("delslice", s, [6, 9, 7])

# A constant tuple in flash as the source.
k = list((10, 20, 30, 40, 50))
check("flash source", k, [10, 20, 30, 40, 50])

# A collection right after a large ship drains the accelerator first.
big = a * 3
gc.collect()
check("collect after ship", (big[0], big[-1], len(big)), (0, 999, 3000))
del big
gc.collect()
m = [x for x in range(64)] + a
check("after collect", (m[63], m[64], m[-1]), (63, 0, 999))
