# PWM: two channels at 1 MHz on pads 2 and 5. The bench measures high time
# and period on each pad; the host model (pwm_config, pwm_wave) gives the
# clocks the firmware's arithmetic must produce. deinit turns a third
# channel off and gives its pad back to GPIO.
from machine import Pin, PWM, mem32

PWM_EN = 0x40000208
PINMUX0 = 0x40000900
a = PWM(Pin(2), freq=1_000_000, duty_u16=16384)
b = PWM(Pin(5), duty_u16=49152)
c = PWM(Pin(7), duty_u16=0)
print(a.freq(), a.duty_u16(), b.duty_u16())
print(hex(mem32[PWM_EN]), hex(mem32[PINMUX0]))
c.deinit()
print(hex(mem32[PWM_EN]), hex(mem32[PINMUX0]))
n = 0
while n < 200:
    n += 1
print('done')
