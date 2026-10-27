# The mailbox natives with no coprocessor image: it stays in reset, so the
# RX FIFO stays empty and the TX FIFO takes 16 words and then reports full.
# _mbox_send returns False then, without the overrun a plain store sets. A
# wide int goes through the firmware fallback (its low 32 bits); a str is a
# TypeError.
from machine import Mailbox, mem32

STATUS = 0x40000108
mb = Mailbox()
print('rx', mb.any(), mb.recv())
n = 0
while n < 100 and mb.send(n):
    n += 1
print('queued before full', n, (mem32[STATUS] >> 8) & 0x1F, (mem32[STATUS] >> 16) & 1)
print('wide int when full', mb.send(1 << 40))
try:
    mb.send('x')
except TypeError as e:
    print('TypeError', e)
print('overrun', (mem32[STATUS] >> 18) & 1)
mem32[0x40000100] = 5
print('overrun after a store', (mem32[STATUS] >> 18) & 1)
mem32[STATUS] = 1 << 18
print('cleared', (mem32[STATUS] >> 18) & 1)
