# Pin.irq(hard=True): decision D2 runs a hard handler at the next soft point
# (not inside the interrupt), with the heap locked, so an allocation raises
# MemoryError. An exception that escapes it prints "Uncaught exception in
# IRQ callback handler" and the exception, and the handler is disabled
# (shared/runtime/mpirq.c, mp_irq_dispatch and mp_irq_handler). The error
# printer is stderr, as on the unix port. Hand-written golden.
from machine import Pin
import time

drv = Pin(1, Pin.OUT, value=0)
inp = Pin(9, Pin.IN)
count = [0]


def hard_ok(p):
    count[0] += 1


inp.irq(hard_ok, Pin.IRQ_RISING, hard=True)
for i in range(3):
    drv.on()
    time.sleep_ms(1)
    drv.off()
    time.sleep_ms(1)
print("hard calls", count[0])


def hard_alloc(p):
    count.append([1, 2, 3])


inp.irq(hard_alloc, Pin.IRQ_RISING, hard=True)
drv.on()
time.sleep_ms(1)
drv.off()
time.sleep_ms(1)
drv.on()
time.sleep_ms(1)
print("after", len(count))
