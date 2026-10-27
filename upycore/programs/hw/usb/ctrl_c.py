# Ctrl-C over USB: the coprocessor rings the KBD doorbell for the armed
# interrupt character instead of passing it on, and the loop ends in
# KeyboardInterrupt. The program waits for a line first, since output
# before the host has enumerated is dropped, and waits again at the end so
# the host's script (ctrl_c.usb) ends the run.
import sys

sys.stdin.readline()
print('looping')
n = 0
try:
    while True:
        n += 1
except KeyboardInterrupt:
    print('KeyboardInterrupt over USB', n > 0)
sys.stdin.read(1)
