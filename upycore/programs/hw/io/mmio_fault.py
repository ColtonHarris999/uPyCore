# An address past the 8 KB MMIO window (registers, then the shared SRAM)
# is still a bus fault.
from machine import mem32

print('before')
mem32[0x40002000] = 1
print('not reached')
