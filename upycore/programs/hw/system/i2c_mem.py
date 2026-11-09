# machine.I2C (extmod/machine_i2c.c) on the I/O core, against the bench's
# 24C02-style target at 0x50 on pads 14 and 15 (+I2C_TARGET): scan, memory
# writes and reads, writeto's ACK count, and a missing device, which raises
# OSError with errno ENODEV (19). Hand-written golden.
from machine import I2C

i2c = I2C(0, freq=100000)
print("scan", i2c.scan())
print("acks", i2c.writeto(0x50, b"\x10hello"))
print("mem", i2c.readfrom_mem(0x50, 0x10, 5))
i2c.writeto_mem(0x50, 0x40, b"\x01\x02\x03")
print("mem2", list(i2c.readfrom_mem(0x50, 0x40, 3)))
i2c.writeto(0x50, b"\x42", False)
print("read", list(i2c.readfrom(0x50, 2)))
try:
    i2c.writeto(0x51, b"x")
except OSError as e:
    print("OSError", e.errno)
