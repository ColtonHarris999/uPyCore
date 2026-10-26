# 1024 ECHO words through the mailbox and back from the coprocessor's
# firmware, in order. The hart sends while the TX FIFO has room and reads
# whatever has come back, so both FIFOs fill across the clock crossing.
# Words on other channels (the coprocessor's USB state) are skipped. The
# payloads and their sum are mpy_periph_model.mbox_echo_payload/_sum.
from machine import Mailbox

ECHO = 0x02
N = 1024
mb = Mailbox()
sent = 0
got = 0
bad = 0
total = 0
while got < N:
    if sent < N and mb.send((ECHO << 24) | ((sent * 40503 + 7) & 0xFFFFFF)):
        sent += 1
    w = mb.recv()
    if w is None or (w >> 24) & 0xFF != ECHO:
        continue
    p = w & 0xFFFFFF
    if p != (got * 40503 + 7) & 0xFFFFFF:
        bad += 1
    total += p
    got += 1
print('echo', got, 'words, out of order', bad, 'sum', total)
print(mb.any(), mb.recv())
