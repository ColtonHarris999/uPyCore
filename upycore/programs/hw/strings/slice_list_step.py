print([1, 2, 3][::2])
a = [1, 2, 3]
try:
    a[::2] = [7, 8]
except NotImplementedError as e:
    print(type(e).__name__, e.args)
else:
    print("assigned")
print(a)
try:
    del a[::2]
except NotImplementedError as e:
    print(type(e).__name__, e.args)
else:
    print("deleted")
print(a)
