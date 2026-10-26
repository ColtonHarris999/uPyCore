# Seventeen unread bytes: the 17th arrives while the FIFO is full, is
# dropped, and sets bit 30. The first 16 come back. Ticks bound the wait,
# because a dropped byte does not wake idle. Bit 30 is read after the
# FIFO is empty, so that load pops nothing.
import machine
from machine import UART, mem32

UART_RX = 0x40000004
TICKS = 0x40000038
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
while u.any() < 16:
    machine.idle()
t = mem32[TICKS]
while mem32[TICKS] - t < 4:
    machine.idle()
u.irq(echo)
while echoed[0] < 18:
    machine.idle()
print(echoed[0], (mem32[UART_RX] >> 30) & 1)
