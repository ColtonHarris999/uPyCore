# micropython.heap_lock / heap_unlock (py/modmicropython.c, py/gc.c in
# MicroPython v1.29.0): a nested depth; heap_unlock returns the depth left;
# an allocation while locked raises MemoryError("memory allocation failed,
# heap is locked"). The locked parts run in functions on locals: storing a
# new global would itself allocate. Hand-written golden.
import micropython


def locked_alloc():
    err = None
    micropython.heap_lock()
    try:
        x = [1, 2, 3]
    except MemoryError as e:
        err = e
    d = micropython.heap_unlock()
    return d, err


def locked_sum():
    n = 0
    micropython.heap_lock()
    for i in range(5):
        n += i
    micropython.heap_unlock()
    return n


d, err = locked_alloc()
print("depth", d)
print(type(err).__name__, err)
def nested():
    micropython.heap_lock()
    micropython.heap_lock()
    a = micropython.heap_unlock()
    b = micropython.heap_unlock()
    return a, b


print(*nested())
y = [4, 5, 6]
print("unlocked", y)
print("sum", locked_sum())
