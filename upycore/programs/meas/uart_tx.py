# Phase 6 measurement: UART transmit throughput. The program writes 4 KB in
# 256-byte writes at BAUD; the bench's line model decodes every byte
# (+MEAS_FILE "rx" times). io_measure.py sets BAUD and +UART_BPS.
from machine import UART
import time

BAUD = 115200
u = UART(0, BAUD)
buf = bytes(range(32, 128)) * 2 + bytes(range(32, 96))
t0 = time.ticks_us()
for i in range(16):
    u.write(buf)
t1 = time.ticks_us()
u.flush()
t2 = time.ticks_us()
print("queued_us", time.ticks_diff(t1, t0), "sent_us", time.ticks_diff(t2, t0))
