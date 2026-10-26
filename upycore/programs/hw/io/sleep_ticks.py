# time.sleep_ms waits on ticks, and ticks_diff/ticks_add wrap at 2**30.
# The unix oracle prints the same lines.
import time

print(time.ticks_diff(5, 3), time.ticks_diff(3, 5))
print(time.ticks_add(1073741823, 1), time.ticks_add(0, -1))
print(time.ticks_diff(time.ticks_add(100, -200), 100))
print(time.ticks_diff(0, 1073741823), time.ticks_diff(1073741823, 0))
t0 = time.ticks_ms()
time.sleep_ms(3)
print(time.ticks_diff(time.ticks_ms(), t0) >= 3)
print(time.sleep_ms(0))
