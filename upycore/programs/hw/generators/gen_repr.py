def named():
    yield 1


g = named()
print(g)
print(type(g).__name__)
print(iter(g) is g)
