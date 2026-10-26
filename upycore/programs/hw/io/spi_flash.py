# SPI against the bench's flash model: JEDEC id, a read, a page program,
# and the read back. CS is GPIO 13. Byte a of the flash starts as
# (7*a + 3) & 0xFF.
from machine import Pin, SPI

cs = Pin(13, Pin.OUT, value=1)
spi = SPI(0, baudrate=4_000_000, polarity=0, phase=0)


def cmd(out, n):
    cs(0)
    buf = bytearray(len(out) + n)
    spi.write_readinto(bytes(out) + bytes(n), buf)
    cs(1)
    return buf[len(out):]


print(cmd(b'\x9f', 3).hex())
print(cmd(b'\x03\x00\x01\x00', 4).hex())
cs(0)
spi.write(b'\x06')
cs(1)
cs(0)
spi.write(b'\x02\x00\x00\x20' + b'upy')
cs(1)
print(cmd(b'\x03\x00\x00\x20', 3))
print(spi.baudrate)
