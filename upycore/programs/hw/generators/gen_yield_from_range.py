def from_list():
    yield from [1, 2, 3]


def from_range():
    yield from range(3)


print("list", list(from_list()))
print("range", list(from_range()))
