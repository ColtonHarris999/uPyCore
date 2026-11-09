# UART receive through the I/O core (machine.UART read, readinto). The
# UART's TX goes to pad 0 and its RX comes from pad 8 (pin mux functions 10
# and 11), which +GPIO_LOOP joins, so the program receives exactly the
# bytes it sends: all 256 byte values, at 1 Mbaud. UART_RX answers four
# bytes a word, so reads of 1 to 5 bytes cover every partial last word.
# readinto fills a bytearray, a memoryview slice of one at an offset, keeps
# to nbytes and to the end of the buffer, takes two commands (255 bytes
# each at most) when the ring holds 256, and copies into a bytearray
# subclass byte by byte; read(300) takes the 256 in two commands too.
# Semantics follow MicroPython v1.29.0 (extmod/machine_uart.c; py/stream.c,
# mp_stream_readinto: at most len(buf) bytes, None when nothing is
# waiting). Hand-written golden.
from machine import UART
import machine
import time

u = UART(0, 1000000)
machine.mem32[0x40000000] = 0x14000000 | 0 | (10 << 8)   # PIN_FUNC pad 0: UART TX
machine.mem32[0x40000000] = 0x14000000 | 8 | (11 << 8)   # PIN_FUNC pad 8: UART RX

pat = bytearray(256)
for i in range(256):
    pat[i] = (i * 37 + 11) & 255          # every byte value once
print("values", len(set(pat)), pat[0], pat[1], pat[255])


def send(b):
    # Send b, then wait until the ring holds that many bytes.
    u.write(b)
    u.flush()
    t0 = time.ticks_ms()
    while u.any() < len(b) and time.ticks_diff(time.ticks_ms(), t0) < 50:
        pass
    return u.any()


print("idle", u.read(), u.readinto(bytearray(4)))

# read(n): one to five bytes, the last word holding 1, 2, 3, 4 and 1 of them.
print("sent", send(pat[0:15]))
o = 0
for n in (1, 2, 3, 4, 5):
    r = u.read(n)
    print("read", n, len(r), type(r).__name__, r == pat[o:o + n])
    o += n
print("left", u.any(), u.read())

# readinto: a bytearray, nbytes, a memoryview slice, nbytes past the end.
print("sent", send(pat[15:35]))
ba = bytearray(6)
print("into", u.readinto(ba), ba == pat[15:21])
ba2 = bytearray(b"......")
print("nbytes", u.readinto(ba2, 3), ba2[:3] == pat[21:24], ba2[3:])
buf = bytearray(12)
mv = memoryview(buf)
print("view", u.readinto(mv[2:9]), buf[2:9] == pat[24:31], buf[:2], buf[9:])
small = bytearray(4)
print("past end", u.readinto(small, 10), small == pat[31:35])
print("left", u.any(), u.readinto(ba))


# Another writable buffer: the byte-at-a-time copy.
class BA(bytearray):
    pass


sub = BA(5)
print("sent", send(pat[35:40]))
print("subclass", u.readinto(sub), sub == pat[35:40], u.any())

# 256 waiting: readinto and read each take two commands, 255 and 1.
print("sent", send(pat))
big = bytearray(300)
print("into 256", u.readinto(big), big[:256] == pat, big[256:] == bytearray(44))
print("sent", send(pat))
r = u.read(300)
print("read 256", len(r), r == pat, u.any(), u.read())
