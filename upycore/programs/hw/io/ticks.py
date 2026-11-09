# time.ticks_* (extmod/modtime.c in MicroPython v1.29.0): a 2**30 period,
# ticks_diff signed and wrap-safe, ticks_add's OverflowError, and the
# counters moving forward together. Hand-written golden.
import time

P = 1 << 30
print(time.ticks_diff(5, 3), time.ticks_diff(3, 5))
print(time.ticks_diff(2, P - 3), time.ticks_diff(P - 3, 2))
print(time.ticks_add(P - 1, 1), time.ticks_add(0, -1) == P - 1)
print(time.ticks_diff(time.ticks_add(100, P // 2 - 1), 100) == P // 2 - 1)
for d in (P // 2, -P // 2 - 1, P):
    try:
        time.ticks_add(0, d)
        print("no error", d)
    except OverflowError as e:
        print("OverflowError:", e)
a = time.ticks_us()
c = time.ticks_cpu()
time.sleep_us(300)
b = time.ticks_us()
c2 = time.ticks_cpu()
print("us forward", time.ticks_diff(b, a) >= 300)
print("cpu forward", time.ticks_diff(c2, c) > 300 * 50)
m0 = time.ticks_ms()
time.sleep_ms(3)
print("ms", time.ticks_diff(time.ticks_ms(), m0) in (3, 4))
print("range", 0 <= time.ticks_ms() < P, 0 <= time.ticks_us() < P, 0 <= time.ticks_cpu() < P)
