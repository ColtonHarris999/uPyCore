# The ninth schedule() is not caught: the oracle's traceback and exit status.
import micropython


def cb(n):
    pass


for i in range(1):
    pass
s = micropython.schedule
s(cb, 0)
s(cb, 1)
s(cb, 2)
s(cb, 3)
s(cb, 4)
s(cb, 5)
s(cb, 6)
s(cb, 7)
s(cb, 8)
