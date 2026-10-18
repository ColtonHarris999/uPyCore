# ticks_us reads the cycle counter. The literals check the 2**30 wrap that
# MicroPython's utime uses, so the lines match the unix port.
from time import ticks_add, ticks_diff, ticks_us

a = ticks_us()
s = 0
i = 0
while i < 200:
    s += i
    i += 1
b = ticks_us()
print(ticks_diff(b, a) > 0)
print(s)
print(ticks_diff(5, 1))
print(ticks_diff(1, 1073741823))
print(ticks_diff(0, 1))
print(ticks_add(1073741822, 4))
print(ticks_add(3, -5))
