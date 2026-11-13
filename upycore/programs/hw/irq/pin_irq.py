# Pin.irq through the I/O core, on the bench's loopback (pad 0 drives pad 8).
# Follows ports/rp2/machine_pin.c and shared/runtime/mpirq.c in MicroPython
# v1.29.0: the handler gets the Pin; irq() returns the irq object, whose
# flags() is the last cause; irq(None) disarms; a soft handler is
# scheduled. Edges are counted by the I/O core; several edges before the
# handler runs give one call. Hand-written golden.
import machine
from machine import Pin
import time

drv = Pin(0, Pin.OUT, value=0)
inp = Pin(8, Pin.IN)
hits = []


def on_edge(p):
    hits.append(p is inp)


irq = inp.irq(on_edge, Pin.IRQ_RISING)
for i in range(5):
    drv.on()
    time.sleep_ms(1)
    drv.off()
    time.sleep_ms(1)
print("rising", len(hits), all(hits), irq.flags())
hits.clear()
inp.irq(on_edge, Pin.IRQ_FALLING)
for i in range(3):
    drv.on()
    time.sleep_ms(1)
    drv.off()
    time.sleep_ms(1)
print("falling", len(hits), irq.flags())
hits.clear()
inp.irq(on_edge, Pin.IRQ_RISING | Pin.IRQ_FALLING)
for i in range(4):
    drv.toggle()
    time.sleep_ms(1)
print("both", len(hits))
inp.irq(None)
hits.clear()
drv.toggle()
time.sleep_ms(2)
print("disarmed", len(hits))
# Several edges before a soft point: one call. Events are held off until
# the I/O core has counted all four edges, so the handler's first chance
# comes after the last one. Left free, the handler can run between two of
# the toggles, and how many calls that gives depends on how many cycles
# the hart takes for them against io_clk, which is not what is tested.
n = []
inp.irq(lambda p: n.append(1), Pin.IRQ_RISING | Pin.IRQ_FALLING)
held = machine.disable_irq()
drv.toggle(); drv.toggle(); drv.toggle(); drv.toggle()
time.sleep_ms(2)
machine.enable_irq(held)
time.sleep_ms(2)
print("coalesced", len(n))
