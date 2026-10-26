# Appends with growth (copy on grow) plus comprehension builds.
def work():
    total = 0
    for r in range(12):
        lst = []
        for i in range(200):
            lst.append(i ^ r)
        sq = [v + 1 for v in lst]
        total += sq[-1] + len(sq)
    return total
print(work())
