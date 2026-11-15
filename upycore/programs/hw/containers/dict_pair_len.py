# A dict built from pairs rejects a tuple or list that is not length 2.
print(dict([(1, "foo")])[1])
try:
    dict(((1,),))
except ValueError:
    print("short")
try:
    dict(((1, 2, 3),))
except ValueError:
    print("long")
try:
    dict([[1]])
except ValueError:
    print("list")
d = {}
d.update([(2, 3), (4, 5)])
print(d[2], d[4])
