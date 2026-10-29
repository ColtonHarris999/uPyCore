# Bulk list work with independent scalar work between the ops.
def work():
    base = list(range(64))
    acc = 0
    for r in range(40):
        a = base + base          # two 64-word copies
        b = a[:]                 # 128-word copy
        t = tuple(b)             # 128-word copy
        c = list(t)
        # independent scalar work while copies drain
        x = r
        for k in range(6):
            x = (x * 3 + k) & 1023
        acc += x + len(c) + c[r] + t[r]
    return acc
print(work())
