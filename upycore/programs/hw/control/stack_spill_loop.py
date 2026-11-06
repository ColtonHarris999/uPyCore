# Loops whose operand stack crosses the register ring on every call. Each
# iteration spills and reloads a chunk; the reload must free it, or the
# frame runs into the spill area ("maximum recursion depth exceeded").
d = {'a': 1}
words = ('a', 'b', 'c', 'a')


def three(n):
    k = 0
    for i in range(n):
        for j in range(n):
            for w in words:
                k += d.get(w, 0)
    return k


def four(n):
    k = 0
    for h in range(n):
        for i in range(n):
            for j in range(n):
                for w in words:
                    k += len(w) + d.get(w, 0)
    return k


def counts(n):
    for _ in range(n):
        c = {}
        for _ in range(n):
            for w in words:
                c[w] = c.get(w, 0) + 1
    return c


print(three(20), four(8), sorted(counts(10).items()))
