# Compare 0: the timer never matches, so 20 ticks produce no edges.
import machine
from machine import Pin, Timer

led = Pin(0, Pin.OUT)


def tog(t):
    led.toggle()


Timer(0).init(period=0, callback=tog, hard=False)
while True:
    machine.idle()
