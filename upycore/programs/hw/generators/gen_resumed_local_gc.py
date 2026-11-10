import gc

def allocate(n):
    if n:
        return allocate(n - 1) + len([n, n + 1])
    gc.collect()
    return 0

def generator():
    kept = [99, 42]
    yield 7
    total = allocate(18)
    kept.append(total)
    gc.collect()
    yield kept
    kept[0] += 1
    yield kept

def relay(g):
    yield from g

g = relay(relay(generator()))
print(next(g))
print(next(g))
gc.collect()
print(next(g))
print(next(g, "done"))
