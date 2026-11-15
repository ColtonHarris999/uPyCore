class Counter:
    def __init__(self, offset):
        self.offset = offset

    def add(self, value):
        return value + self.offset


def work():
    counter = Counter(3)
    seen = []
    lookup = {0: 5, 1: 7}
    total = 0
    for i in range(200):
        seen.append(counter.add(i))
        total += lookup.get(i & 1) + seen[-1]
    return total


print(work())
