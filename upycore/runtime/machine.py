# machine, MicroPython v1.29.0 signatures, on the I/O core. Frozen only into
# programs that import it (mpy_build.RUNTIME_MODULES). Spec:
# upycore/docs/mpy_io_core.md (machine).
#
# The bridge window is reached through the firmware's _io module: _io.rd(off)
# and _io.wr(off, w) are one word load or store at 0x4000_0000 + off.
import _io

_BASE = 0x40000000
_END = 0x40001000


class mem:
    # mem8 / mem16 / mem32 (extmod/machine_mem.c). Only the bridge window
    # is behind it; a word is read as a signed 32-bit int, as on a 32-bit
    # port. Bytes and halfwords are not bus accesses here, so only mem32
    # is provided.
    def __init__(self, size):
        self._size = size

    def __repr__(self):
        return "<%u-bit memory>" % (8 * self._size)

    def _addr(self, a):
        a = a & 0xFFFFFFFF
        if a & (self._size - 1):
            raise ValueError("address %08x is not aligned to %d bytes" % (a, self._size))
        if a < _BASE or a >= _END:
            raise ValueError("address %08x is not in the I/O window" % a)
        return a - _BASE

    def __getitem__(self, a):
        return _io.rd(self._addr(a))

    def __setitem__(self, a, v):
        _io.wr(self._addr(a), v)


mem32 = mem(4)
