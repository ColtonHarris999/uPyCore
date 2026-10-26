# Slice A: an address past the 4 KB MMIO window is still a bus fault.
from machine import mem32

print('before')
mem32[0x40001000] = 1
print('not reached')
