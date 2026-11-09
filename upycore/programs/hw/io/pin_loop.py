# machine.Pin through the I/O core, with the bench's loopback (+GPIO_LOOP:
# pad i and pad i^8 are one net). Pin semantics follow MicroPython v1.29.0
# (extmod/machine_pin.c, ports/rp2/machine_pin.c): value() reads the pad,
# on/off/toggle/high/low drive an output, a pull-up reads 1 with nothing
# driving, OPEN_DRAIN drives only a 0. Hand-written golden.
from machine import Pin

out = Pin(0, Pin.OUT, value=0)
inp = Pin(8, Pin.IN)
print(out, inp)
print("low", inp.value(), out.value())
out.on()
print("on", inp.value())
out.off()
print("off", inp.value())
out.toggle()
print("toggle", inp.value())
out(0)
print("call", inp(), out.mode(), inp.mode())
out.high()
print("high", inp.value())
out.low()
print("low", inp.value())
# Pull-up with nothing driving the net.
p = Pin(3, Pin.IN, Pin.PULL_UP)
print("pull_up", p.value(), p.pull())
p.init(pull=Pin.PULL_DOWN)
print("pull_down", p.value())
# Open drain: 0 drives the net low, 1 releases it to the far pin's pull-up.
od = Pin(5, Pin.OPEN_DRAIN, value=1)
far = Pin(13, Pin.IN, Pin.PULL_UP)
print("od released", far.value())
od.value(0)
print("od low", far.value())
od.value(1)
print("od released", far.value())
seen = []
for i in range(8):
    Pin(i, Pin.OUT, value=i & 1)
for i in range(8):
    seen.append(Pin(i + 8, Pin.IN).value())
print("bus", seen)
try:
    Pin(16)
except ValueError as e:
    print("ValueError:", e)
try:
    Pin(1, 7)
except ValueError as e:
    print("ValueError:", e)
