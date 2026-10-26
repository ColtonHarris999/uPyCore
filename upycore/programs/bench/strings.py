# String concatenation, slicing and join.
def work():
    s = "abcdefghij" * 20
    total = 0
    for r in range(30):
        t = s + s
        u = t[r:r + 150]
        v = "-".join([u[:10], u[10:20], u[20:30]])
        total += len(t) + len(u) + len(v) + ord(u[5])
    return total
print(work())
