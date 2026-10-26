# The coprocessor's KBD doorbell is Ctrl-C: KBD_TEST asks it to ring once,
# and the busy loop below ends in KeyboardInterrupt at a jump.
import micropython
from machine import Mailbox

micropython.kbd_intr(3)
Mailbox().send(0x01020000)
n = 0
try:
    while True:
        n += 1
except KeyboardInterrupt:
    print('KeyboardInterrupt from the coprocessor', n > 0)
