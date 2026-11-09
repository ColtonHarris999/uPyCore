# Phase 6 measurement: the I/O island busy. UART0 sends at 1 Mbaud, a pin
# toggles, SPI transfers run at 5 MHz (MISO reads an idle pad) and a 1 kHz
# timer runs a callback, all at once, for about 10 ms;
# io_measure.py power records the island's switching activity from 2 ms on.
from machine import Pin, SPI, Timer, UART
import time

n = 0


def cb(t):
    global n
    n += 1


u = UART(0, 1000000)
p = Pin(0, Pin.OUT)
spi = SPI(0, baudrate=5000000)
t = Timer(0, freq=1000, callback=cb)
buf = bytes(range(64))
rx = bytearray(64)
t0 = time.ticks_ms()
while time.ticks_diff(time.ticks_ms(), t0) < 10:
    u.write(buf)
    p.toggle()
    spi.write_readinto(buf, rx)
t.deinit()
u.flush()
print("active done", n)
