# machine.SPI (extmod/machine_spi.c) on the I/O core, against the bench's
# SPI NOR flash on pads 10-13 (+SPI_FLASH): JEDEC id (EF 40 18), a read
# (byte a holds (7a + 3) & 255), and write_readinto. Chip select is a Pin.
# Hand-written golden.
from machine import Pin, SPI

cs = Pin(13, Pin.OUT, value=1)
spi = SPI(0, baudrate=2000000)
cs(0)
spi.write(b"\x9f")
print("id", spi.read(3).hex())
cs(1)
cs(0)
spi.write(bytes([0x03, 0, 0, 16]))
data = spi.read(8)
cs(1)
print("data", list(data))
cs(0)
buf = bytearray(5)
spi.write_readinto(bytes([0x03, 0, 0, 100, 0]), buf)
cs(1)
print("wr", list(buf[4:]))
cs(0)
spi.write(bytes([0x03, 0, 0, 0]))
big = spi.read(100)
cs(1)
print("long", all(big[a] == (7 * a + 3) & 255 for a in range(100)))
spi.deinit()
