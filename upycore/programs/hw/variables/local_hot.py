# Hot locals live in a side cache. The sum loop hits that cache, the
# call must flush it, and the list must still be a root at collection.

def inc(x):
    return x + 1


def accum():
    s = 0
    i = 0
    while i < 50:
        s = s + i
        i = i + 1
    return s


def nest():
    a = 10
    b = inc(a)
    return a + b


def keep():
    import gc
    a = [1, 2, 3]
    s = 0
    i = 0
    while i < 20:
        s = s + i
        i = i + 1
    gc.collect()
    return a[0] + a[2] + s


print(accum())
print(nest())
print(keep())
