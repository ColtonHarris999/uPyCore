# UART at 115200 8N1 through the I/O core: the bench's line model sends a
# line 4 ms after boot; the program reads it, prints it, and sends it
# back in upper case, which the line model decodes (the .io golden). UART
# methods follow MicroPython v1.29.0 (extmod/machine_uart.c): read() with
# nothing waiting returns None, any() counts the bytes waiting, write()
# returns the count. Hand-written golden.
from machine import UART
import time

u = UART(0, 115200)
# The repr shows the rate the divider gives (as rp2's does), which depends
# on io_clk; the clock-ratio sweep runs this test at three io clocks.
r = repr(u)
print(r[:17], abs(int(r[17:23]) - 115200) < 200, r[23:])
print("idle read", u.read(), u.any())
t0 = time.ticks_ms()
while u.any() < 12 and time.ticks_diff(time.ticks_ms(), t0) < 20:
    pass
n = u.any()
line = u.readline()
print("any", n, "line", line)
print("wrote", u.write(line.upper()))
u.write(b"#")
u.write("ok\r\n")
u.flush()
print("txdone", u.txdone(), "rest", u.read())
