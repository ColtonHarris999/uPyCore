import gc

# A chunked star stores 80-byte blocks in ARGBUF. pad is one such block.
# After the heap has no other 80-byte hole, dropping pad lets the star
# call's collector retry free exactly that hole. The first chunk block
# fits and the second raises. The pointer must not stay a root.


def f(*a):
    return len(a)


def fill():
    # Big blocks first, then 64-byte ones into a list sized in advance, so
    # no list growth can fail before the heap has no 64-byte hole left.
    try:
        while True:
            blobs.append(bytes(4096))
    except MemoryError:
        pass
    i = 0
    try:
        while i < len(small):
            small[i] = bytes(64)
            i += 1
    except MemoryError:
        pass


# Bind every global first, so the module dict does not grow after the
# baseline and count as held memory.
seq = blobs = small = pad = got = now = None
gc.collect()
empty = gc.mem_free()
seq = (1,) * 200
blobs = []
small = [None] * 600
pad = bytes(64)
got = 1
fill()
pad = None
try:
    got = f(*seq)
except MemoryError:
    pass
del seq, blobs, small
gc.collect()
now = gc.mem_free()
if got == 1 and now > empty - 80:
    print("room")
    print("oom")
    print("freed")
elif got == 1:
    print("held", empty - now)
else:
    print("ran", got, empty - now)
