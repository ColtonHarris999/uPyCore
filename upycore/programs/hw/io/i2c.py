# I2C against the bench's targets on pads 14 (SCL) and 15 (SDA): a
# 24C02-style EEPROM at 0x50 (byte a starts as a) and a 16-byte device at
# 0x42 (byte a starts as a ^ 0xA0) that stretches SCL 6000 clocks after
# every ACK.
import errno
from machine import I2C

i2c = I2C(0, freq=400_000)
print(i2c.scan(), i2c.freq)
i2c.writeto_mem(0x50, 0x10, b'upy')
print(i2c.readfrom_mem(0x50, 0x10, 4))
print(i2c.writeto(0x50, b'\x20\x01\x02'))
print(i2c.readfrom(0x50, 2))
buf = bytearray(3)
i2c.readfrom_mem_into(0x50, 0x20, buf)
print(buf)
# The stretching target, within the default timeout.
print(i2c.readfrom_mem(0x42, 3, 2))
try:
    i2c.writeto(0x33, b'x')
except OSError as e:
    print(e, e.errno == errno.ENODEV)
# A 10 us limit is 480 clocks, shorter than the stretch.
slow = I2C(0, timeout=10)
try:
    slow.readfrom_mem(0x42, 0, 1)
except OSError as e:
    print(e, e.errno == errno.ETIMEDOUT)
i2c.init(timeout=50_000)
print(i2c.readfrom_mem(0x42, 0, 1))
# Primitive operations.
i2c.start()
print(i2c.write(b'\xa0\x10'))
i2c.start()
print(i2c.write(b'\xa1'))
buf = bytearray(2)
i2c.readinto(buf)
i2c.stop()
print(buf)
