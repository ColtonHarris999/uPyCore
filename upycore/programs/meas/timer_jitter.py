# Phase 6 measurement: a 1 kHz machine.Timer callback's period as the
# hart sees it (the time between runs of cb's first opcode, +MEAS_PC):
# first while the main program sleeps, then while it spins; pad 4 marks
# the change.
from machine import Pin, Timer
import time

N = const(300)
n = 0


def cb(t):
    global n
    n += 1


mark = Pin(4, Pin.OUT, value=0)
t = Timer(0, mode=Timer.PERIODIC, freq=1000, callback=cb)
while n < N:
    time.sleep_ms(1)
mark.value(1)
while n < 2 * N:
    pass
t.deinit()
mark.value(0)
print("ticks", n)
