import gc

# A chunked star stores 80-byte blocks in ARGBUF. Leave one contiguous
# 80-byte hole and less than a second block, so the first block is rooted
# and the next alloc raises. After the exception those slots must not
# keep the block alive.


def f(*a):
    return len(a)


gc.collect()
empty = gc.mem_free()
seq = (1,) * 200
blobs = []
try:
    while True:
        blobs.append(bytes(4096))
except MemoryError:
    pass
small = []
try:
    while True:
        small.append(bytes(64))
except MemoryError:
    pass
tiny = []
while gc.mem_free() >= 32:
    try:
        tiny.append(bytes(1))
    except MemoryError:
        break
if small:
    small.pop()
left = gc.mem_free()
if 80 <= left < 112:
    print("room")
else:
    print("room-bad", left)
try:
    print(f(*seq))
except MemoryError:
    print("oom")
del seq, blobs, small, tiny
gc.collect()
now = gc.mem_free()
if now > empty - 80:
    print("freed")
else:
    print("held", now, empty)
