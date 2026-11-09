# Ctrl-C over USB: the I/O core turns the armed interrupt character from
# CDC OUT into the KBD event instead of a console byte, and the loop ends
# in KeyboardInterrupt. The program waits for a line first, so the host's
# Ctrl-C (ctrl_c.usb) arrives while it loops. Ported from the epic
# branch's test. Hand-written golden.
import sys

sys.stdin.readline()
print('looping')
n = 0
try:
    while True:
        n += 1
except KeyboardInterrupt:
    print('KeyboardInterrupt over USB', n > 0)
