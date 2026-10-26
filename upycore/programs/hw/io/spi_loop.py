# SPI loopback: MOSI is wired to MISO, so every mode returns what it sent.
from machine import SPI

data = bytes(range(0, 250, 7))
for mode in range(4):
    spi = SPI(0, baudrate=8_000_000, polarity=mode >> 1, phase=mode & 1)
    got = bytearray(len(data))
    spi.write_readinto(data, got)
    print(mode, got == data, spi.read(3, 0x5A).hex())
