# Phase 6 measurement: how fast Python drives a pin through the I/O core.
# Pad 0: Pin.toggle(); pad 1: Pin.value(v) with v alternating; pad 2:
# on()/off() pairs. Each loop is 200 changes; the bench logs every pad
# change (iocore/tools/io_measure.py, +MEAS_FILE).
from machine import Pin

a = Pin(0, Pin.OUT, value=0)
b = Pin(1, Pin.OUT, value=0)
c = Pin(2, Pin.OUT, value=0)
for i in range(200):
    a.toggle()
v = 0
for i in range(200):
    v ^= 1
    b.value(v)
for i in range(100):
    c.on()
    c.off()
print("done")
