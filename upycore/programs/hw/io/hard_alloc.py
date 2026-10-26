# A hard Timer callback that allocates: the heap is locked, so it raises
# MemoryError. The banner and the traceback go to stderr, the timer source
# is disabled, and the program after the handler still runs.
import machine
from machine import Timer, mem32

TICKS = 0x40000038
IRQ_ENABLE = 0x40000014
hits = [0]


def cb(t):
    hits[0] += 1
    x = [1, 2, 3]


Timer(0).init(period=2, callback=cb, hard=True)
t = mem32[TICKS]
while mem32[TICKS] - t < 8:
    machine.idle()
print('after', hits[0], mem32[IRQ_ENABLE] & 1)
