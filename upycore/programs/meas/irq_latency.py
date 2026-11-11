# Phase 6 measurement: pin edge to the first bytecode of the Pin.irq
# handler. The bench drives rising edges on pad 3 (+PULSE) and logs each
# edge and each time the core runs cb's first opcode (+MEAS_PC); pad 4
# marks the phases: 0 while the main program sleeps (time.sleep_ms, the
# hart waits in _wfe), 1 while it spins in a loop (soft points at the
# loop's jumps), first with a soft handler and then with hard=True.
from machine import Pin
import time

N = const(250)
n = 0


def cb(p):
    global n
    n += 1


mark = Pin(4, Pin.OUT, value=0)
pin = Pin(3, Pin.IN)
irq = pin.irq(cb, Pin.IRQ_RISING)
while n < N:
    time.sleep_ms(1)
mark.value(1)
while n < 2 * N:
    pass
mark.value(0)
irq = pin.irq(cb, Pin.IRQ_RISING, hard=True)
while n < 3 * N:
    time.sleep_ms(1)
mark.value(1)
while n < 4 * N:
    pass
mark.value(0)
pin.irq(None)
print("edges", n)
