# Phase 6 measurement: UART receive throughput. The bench sends COUNT bytes
# back to back at BAUD (+UART_IN_PATTERN); the program reads them into one
# buffer as they come and checks the pattern ('a'..'z' repeating) after the
# last one, so the check does not slow the reading. io_measure.py sets
# BAUD, COUNT and +UART_BPS.
from machine import UART
import time

BAUD = 115200
COUNT = 2048
u = UART(0, BAUD)
buf = bytearray(COUNT)
mv = memoryview(buf)
got = 0
t0 = None
last = time.ticks_ms()
while got < COUNT and time.ticks_diff(time.ticks_ms(), last) < 50:
    k = u.readinto(mv[got:])
    if k:
        if t0 is None:
            t0 = time.ticks_us()
        got += k
        last = time.ticks_ms()
t1 = time.ticks_us()
bad = 0
for i in range(got):
    if buf[i] != 97 + i % 26:
        bad += 1
print("got", got, "bad", bad, "us", time.ticks_diff(t1, t0) if t0 is not None else 0)
