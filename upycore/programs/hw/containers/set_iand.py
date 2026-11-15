u = {1}
u &= set()
print(u)
u = {1, 2}
u &= {2}
print(u)
u = {1}
print(u & set())
u = {1}
u -= set()
print(u)

u = {1, 2}
u &= frozenset({2})
print(u)
u = frozenset({1, 2})
u &= {2}
print(type(u).__name__)
print(u)
u = {1, 2, 3}
r = u & frozenset({1, 3})
print(len(r), 1 in r, 2 in r, 3 in r)
u = frozenset({1, 2})
print(u & {2})
u = {1, 2}
u.intersection_update({2, 3})
print(u)
u = {1}
u.intersection_update(frozenset())
print(u)
