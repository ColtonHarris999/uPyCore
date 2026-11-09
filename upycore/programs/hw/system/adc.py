# machine.ADC (extmod/machine_adc.c): read_u16 is the converter's 12-bit
# code left-aligned; the bench's converter answers channel c with
# (273 * c + 100) & 0xFFF. A Pin's id is its channel. Hand-written golden.
from machine import ADC, Pin

for ch in (0, 3, 15):
    print(ch, ADC(ch).read_u16())
print(ADC(Pin(5)).read_u16())
