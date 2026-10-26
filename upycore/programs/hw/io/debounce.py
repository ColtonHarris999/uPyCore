# Debounce: a rising-edge pin IRQ accepts a press only when 5 ticks have
# passed since the last one it accepted. The bench bounces pin 0 three
# times per press; the accepted count is what the host model computes.
# The count also goes out on GPIO_OUT.
import machine
import time
from machine import Pin, mem32

GPIO_OUT = 0x40000008
last = [-100]
presses = [0]


def press(p):
    now = time.ticks_ms()
    if time.ticks_diff(now, last[0]) >= 5:
        last[0] = now
        presses[0] += 1
        mem32[GPIO_OUT] = presses[0]


Pin(0, Pin.IN).irq(press, Pin.IRQ_RISING)
while True:
    machine.idle()
