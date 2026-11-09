# machine.PWM (extmod/machine_pwm.c signatures) on the I/O core: PWM on pad
# 2, read back on pad 10 (+GPIO_LOOP), sampled; freq() is the frequency the
# divider gives, duty_u16() what was set. Hand-written golden.
from machine import Pin, PWM
import time

pwm = PWM(Pin(2), freq=1000, duty_u16=16384)
sense = Pin(10, Pin.IN)
print("freq", pwm.freq(), "duty", pwm.duty_u16())
high = 0
for i in range(200):
    high += sense.value()
print("quarter", 30 <= high <= 70)
pwm.duty_u16(49152)
time.sleep_ms(2)
high = 0
for i in range(200):
    high += sense.value()
print("three quarters", 130 <= high <= 170)
pwm.duty_u16(0)
time.sleep_ms(2)
print("off", sense.value())
pwm.duty_u16(65535)
time.sleep_ms(2)
print("on", sense.value())
pwm.deinit()
