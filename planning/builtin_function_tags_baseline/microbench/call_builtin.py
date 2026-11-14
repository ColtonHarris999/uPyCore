def work():
    values = list(range(16))
    total = 0
    for i in range(200):
        total += len(values)
        total += isinstance(values, list)
        total += abs(i - 100)
    return total


print(work())
