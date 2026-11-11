# machine.Timer callbacks (extmod/machine_timer.c signatures): a periodic
# timer every 2 ms for 21 ms calls back ten times; ONE_SHOT once; a soft
# callback (hard=False) is scheduled; deinit stops it. The callback gets the
# Timer. Hand-written golden.
from machine import Timer
import time

n = [0]


def tick(t):
    n[0] += 1


t = Timer(0, mode=Timer.PERIODIC, period=2, callback=tick)
time.sleep_ms(21)
t.deinit()
print("periodic", n[0])
time.sleep_ms(5)
print("after deinit", n[0])
got = []
t1 = Timer(1, mode=Timer.ONE_SHOT, period=3, callback=lambda tm: got.append(tm is t1))
time.sleep_ms(10)
print("one shot", got)
soft = []
t2 = Timer(2, mode=Timer.PERIODIC, freq=1000, callback=lambda tm: soft.append([1]), hard=False)
time.sleep_ms(5)
t2.deinit()
print("soft", 4 <= len(soft) <= 5)
