# Integer mul / mod / floordiv heavy.
def work(n):
    s = 0
    x = 12345
    for i in range(1, n):
        x = (x * 1103 + 12345) % 65521
        s += x // 7 + (i * i) % 97
    return s
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a
print(work(1500), sum(gcd(i * 7919, 1000003) for i in range(1, 200)))
