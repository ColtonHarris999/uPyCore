# Slice A: a one-opcode store reaches gpio_out, a UART_RX load pops, and a
# misaligned word raises like machine.mem32 on v1.29.0. The bench strobes
# 0x41 and 0x42 into the UART at cycle 10 and 20.
import machine
from machine import mem32

GPIO_OUT = 0x40000008
UART_RX = 0x40000004

mem32[GPIO_OUT] = 0xA5
print(hex(mem32[GPIO_OUT]))
mem32[GPIO_OUT] = 0xFFFFFFFF
print(mem32[GPIO_OUT])
a = mem32[UART_RX]
b = mem32[UART_RX]
c = mem32[UART_RX]
print(hex(a & 0xFF), a < 0, hex(b & 0xFF), hex(c))
try:
    mem32[GPIO_OUT + 1]
except ValueError as e:
    print(e)
print(machine.mem8[GPIO_OUT])
