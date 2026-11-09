# UART.irq(handler, UART.IRQ_RXIDLE) (extmod/machine_uart.c; the IRQ values
# are rp2's): the handler runs after the line model's bytes arrive and the
# line goes quiet, and gets the UART; flags() is the cause. Hand-written
# golden.
from machine import UART
import time

u = UART(0, 115200)
seen = []
irq = u.irq(lambda x: seen.append(x.any()), UART.IRQ_RXIDLE)
t0 = time.ticks_ms()
while not seen and time.ticks_diff(time.ticks_ms(), t0) < 30:
    time.sleep_ms(1)
print("rxidle", seen, irq.flags() == UART.IRQ_RXIDLE, u.read())
