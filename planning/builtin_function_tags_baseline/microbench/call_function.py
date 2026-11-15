def add(a, b):
    return a + b


def bind(offset):
    def apply(value):
        return add(value, offset)
    return apply


def work():
    apply = bind(3)
    total = 0
    for i in range(200):
        total = add(total, apply(i))
    return total


print(work())
