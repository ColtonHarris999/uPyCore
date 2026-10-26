# Pin.OUT drives gpio_oe; Pin.IN releases it. Pulls go to the pad pins.
from machine import Pin, mem32

GPIO_OE = 0x40000048
GPIO_PU = 0x4000004C
a = Pin(5, Pin.OUT)
b = Pin(7, Pin.OUT, value=1)
print(hex(mem32[GPIO_OE]), b.value())
c = Pin(9, Pin.IN, Pin.PULL_UP)
print(hex(mem32[GPIO_PU]))
a.init(Pin.IN)
print(hex(mem32[GPIO_OE]))
b.init(Pin.IN)
print(hex(mem32[GPIO_OE]))
