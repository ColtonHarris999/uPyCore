# Blink: pin 0 toggles every 5 ms, ten times. The bench records each pad
# change; the .io golden is its MPY_IO summary (ten changes, nine 5 ms
# intervals, rounded to the millisecond). time.sleep_ms follows MicroPython
# v1.29.0 (extmod/modtime.c): it sleeps at least that long. Hand-written
# golden.
from machine import Pin
import time

led = Pin(0, Pin.OUT, value=0)
for i in range(10):
    led.toggle()
    time.sleep_ms(5)
print("done")
