# The shared SRAM (machine.Mailbox.SHARED) is outside the GC pool and both
# root spans: words there that point into a dropped object do not keep it
# alive. The coprocessor sees the same memory: COPY moves word 0 to word
# 100 and answers on the COPY channel.
import gc
import machine

SH = machine.Mailbox.SHARED
mem = machine.mem32
mb = machine.Mailbox()

gc.collect()
free0 = gc.mem_free()
big = bytearray(20000)
for i in range(16):
    mem[SH + 4 * i] = id(big) + 4 * i
gc.collect()
print('held while referenced', free0 - gc.mem_free() >= 20000)
del big
gc.collect()
print('freed with pointers in shared SRAM', free0 - gc.mem_free() < 1000)

COPY = 0x03
mb.send((COPY << 24) | (100 << 10) | 0)
while True:
    w = mb.recv()
    if w is not None and (w >> 24) & 0xFF == COPY:
        break
print('the coprocessor copied it', mem[SH + 400] == mem[SH])
