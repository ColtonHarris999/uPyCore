# Ctrl-C on the UART raises KeyboardInterrupt at the loop's jump. The bench
# strobes 0x03 while the loop runs; kbd_intr(3) arms the character.
import micropython

micropython.kbd_intr(3)
n = 0
try:
    while True:
        n += 1
except KeyboardInterrupt:
    print('KeyboardInterrupt', n > 0)
micropython.kbd_intr(-1)
while True:
    pass
