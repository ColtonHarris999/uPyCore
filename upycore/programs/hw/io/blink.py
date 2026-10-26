# Blink: a soft Timer callback toggles pin 0 every 4 ticks. The bench stops
# after 20 ticks and checks the GPIO_OUT edge mask against the host model
# (mpy_periph_model.blink_edge_mask). The loop idles between ticks.
import machine
from machine import Pin, Timer

led = Pin(0, Pin.OUT)


def tog(t):
    led.toggle()


Timer(0).init(period=4, callback=tog, hard=False)
while True:
    machine.idle()
