# soft_reset, then reset: three boots of one image, told apart by
# reset_cause(). Each boot starts from zeroed SRAM: the errno sysroot slot
# (0x2000_8080 + 4*30) reads 0 until errno is imported, globals are fresh,
# and machine is built again.
import machine

c = machine.reset_cause()
print('boot', c, 'seen' in globals(), machine.mem32[0x2000_8080 + 4 * 30])
import errno
seen = errno.EIO
if c == machine.PWRON_RESET:
    machine.soft_reset()
if c == machine.SOFT_RESET:
    machine.reset()
print(machine.unique_id(), c == machine.HARD_RESET)
