# Per-pin handlers: pin 0 and pin 1 each keep their own handler on the one
# GPIO slot, and both fire in edge order. Pin 2 is hard and pin 3 soft on
# the same slot: the hard dispatch calls pin 2 and schedules pin 3.
import machine
from machine import Pin

log = []
hard_hits = [0]


def on_a(p):
    log.append(('a', p.id))


def on_b(p):
    log.append(('b', p.id))


def on_hard(p):
    hard_hits[0] += 1


def on_soft(p):
    log.append(('soft', p.id, hard_hits[0]))


Pin(0, Pin.IN).irq(on_a, Pin.IRQ_RISING)
Pin(1, Pin.IN).irq(on_b, Pin.IRQ_RISING)
while len(log) < 2:
    machine.idle()
Pin(2, Pin.IN).irq(on_hard, Pin.IRQ_RISING, hard=True)
Pin(3, Pin.IN).irq(on_soft, Pin.IRQ_RISING)
while len(log) < 3:
    machine.idle()
print(log)
print(hard_hits[0])
