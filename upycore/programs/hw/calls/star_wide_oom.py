import gc

# A chunked star stores 80-byte blocks in ARGBUF. pad is one such block.
# After the heap has no other 80-byte hole, dropping pad lets the star
# call's collector retry free exactly that hole. The first chunk block
# fits and the second raises. The pointer must not stay a root.


def f(*a):
    return len(a)


def fill():
    try:
        while True:
            blobs.append(bytes(4096))
    except MemoryError:
        pass
    try:
        while True:
            small.append(bytes(64))
    except MemoryError:
        pass


gc.collect()
empty = gc.mem_free()
seq = (1,) * 200
blobs = []
small = []
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
