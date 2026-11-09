# machine.mem32 checks alignment first, as extmod/machine_mem.c
# (machine_mem_get_addr) does in MicroPython v1.29.0, and reaches only the
# bridge window here. Hand-written golden.
import machine

print(machine.mem32)
for a in (0x40000002, 0x40000001, 0x20000000, 0x40001000):
    try:
        machine.mem32[a]
    except ValueError as e:
        print("ValueError:", e)
print(machine.mem32[0x40000000 + 0x24])
