# time.sleep_ms and sleep_us against ticks_us: each sleep lasts at least
# the time asked (MicroPython v1.29.0 guarantees no shorter sleep) and,
# polled here, at most 150 µs more. Hand-written golden.
import time

ok = True
for ms in (1, 2, 5, 10, 20):
    t0 = time.ticks_us()
    time.sleep_ms(ms)
    d = time.ticks_diff(time.ticks_us(), t0)
    good = ms * 1000 <= d <= ms * 1000 + 150
    ok = ok and good
    print("sleep_ms", ms, good)
for us in (50, 100, 500, 2000):
    t0 = time.ticks_us()
    time.sleep_us(us)
    d = time.ticks_diff(time.ticks_us(), t0)
    good = us <= d <= us + 150
    print("sleep_us", us, good)
t0 = time.ticks_ms()
time.sleep(0.01)
print("sleep float", time.ticks_diff(time.ticks_ms(), t0) in (10, 11))
print("all", ok)
