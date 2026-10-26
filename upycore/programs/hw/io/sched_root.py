# Slice B: the schedule ring is a GC root. The closure below is reachable
# only from the ring when gc.collect() runs, and straight-line allocations
# then reuse any block that collection freed. The callback still runs and
# sees its list. An int argument whose payload is a heap address does not
# keep that address alive. No jump runs between schedule() and the checks.
import gc
import micropython

out = []
d = f0 = f1 = a = b = c = None


def nop(x):
    pass


def make():
    big = [10, 20, 30]

    def cb(x):
        out.append((x, big))
    return cb


micropython.schedule(make(), 7)
gc.collect()
a = [0] * 64
b = [1] * 64
c = [2] * 64
d = bytearray(4000)
micropython.schedule(nop, id(d))
gc.collect()
f0 = gc.mem_free()
d = None
gc.collect()
f1 = gc.mem_free()
print(out)
print(f1 - f0 >= 4000)
n = 0
while n < 3:
    n += 1
print(out)
