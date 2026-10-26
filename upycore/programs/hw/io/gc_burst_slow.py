# 64 bytes at the modeled baud rate while gc.collect() stalls the reader.
# The bench starts the frames at the first machine.idle(), once the heap
# is built.
# 1000 clocks a bit: about six bytes arrive during the collection, so the
# 16-entry FIFO holds them and all 64 arrive intact.
import gc
import machine
import time
from machine import UART, mem32

UART_RX = 0x40000004
u = UART(0, baudrate=48000)
junk = [[i] * 8 for i in range(300)]
buf = bytearray(64)
n = 0
ov = 0
ok = True
ok16 = True
machine.idle()
while u.any() == 0:
    pass
gc.collect()
t = time.ticks_ms()
while n < 64 and time.ticks_diff(time.ticks_ms(), t) < 30:
    b = u.read()
    if b:
        for x in b:
            if n < 64:
                buf[n] = x
                n += 1
for i in range(n):
    if buf[i] != i:
        ok = False
        if i < 16:
            ok16 = False
ov = (mem32[UART_RX] >> 30) & 1
print(n, ok, ov)
