# heap_lock returns None, heap_unlock returns the new depth, and an
# allocation while locked raises without collecting. Globals are created
# first: a store that grows the dict would allocate while locked.
import micropython

r = d = d2 = x = e = None
r = micropython.heap_lock()
micropython.heap_unlock()
print(r)
micropython.heap_lock()
print(micropython.heap_unlock())
micropython.heap_lock()
micropython.heap_lock()
d = micropython.heap_unlock()
d2 = micropython.heap_unlock()
print(d, d2)
micropython.heap_lock()
try:
    x = [1, 2, 3]
except MemoryError as e:
    micropython.heap_unlock()
    print(type(e).__name__, e)
x = [1, 2, 3]
print(x)
