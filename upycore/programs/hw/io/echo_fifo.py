# Echo with the 16-entry RX FIFO. The bench strobes one byte each time the
# core is idle. 0x41 and 0x42 come back one at a time. Then the callback
# disarms the UART source, so 0x43 and 0x44 stay buffered; re-arming it
# delivers the pending source and both come back in order. No byte is
# dropped, so bit 30 stays clear.
import machine
from machine import UART, mem32

UART_RX = 0x40000004
u = UART(0)
echoed = [0]


def echo(u):
    while u.any():
        u.write(u.read(1))
        echoed[0] += 1
    if echoed[0] == 2:
        u.irq(None)


u.irq(echo)
while echoed[0] < 2:
    machine.idle()
while u.any() < 2:
    machine.idle()
held = u.any()
u.irq(echo)
while echoed[0] < 4:
    machine.idle()
print(echoed[0], held, (mem32[UART_RX] >> 30) & 1)
