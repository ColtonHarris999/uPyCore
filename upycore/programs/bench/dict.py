# Dict growth, copy, and update.
def work():
    total = 0
    for r in range(6):
        d = {}
        for i in range(120):
            d[i * 7 + r] = i
        e = d.copy()
        e.update({1: 2, 3: 4})
        total += len(e) + e[7 + r]
    return total
print(work())
