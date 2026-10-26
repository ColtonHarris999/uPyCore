# ADC against the bench's converter: channel c reads
# ((273 * c + 100) & 0xFFF) << 4 (mpy_periph_model.adc_read_u16).
from machine import ADC, Pin

print([ADC(c).read_u16() for c in (0, 1, 5, 15)])
a = ADC(Pin(3))
print(a.read_u16(), a.read_u16() == ((273 * 3 + 100) & 0xFFF) << 4)
try:
    ADC(16)
except ValueError as e:
    print('ValueError', e)
