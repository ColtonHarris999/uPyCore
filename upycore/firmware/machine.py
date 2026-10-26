# machine: the MMIO window (upycore/docs/mpy_peripherals.md) as the
# MicroPython v1.29.0 module surface. The module is built on the first
# import and kept in SR_MACHINE, so programs that never import it pay
# nothing at boot.
from ._abi import *

MMIO = const(1073741824)        # 0x4000_0000


def _w32(v):
    # Low 32 bits of an int, as the signed word an INT payload holds.
    v = v & 0xFFFFFFFF
    if v >= 0x80000000:
        v -= 4294967296
    return v


def _mem_addr(addr, width):
    if not _isint(addr):
        raise TypeError("can't convert to int")
    if addr & (width - 1):
        a = _hexaddr(addr)
        while _slen(a) < 8:
            a = _cat('0', a)
        raise ValueError(_s('address ', a, ' is not aligned to ', _istr(width), ' bytes'))
    return addr


def _mem_get(width, addr):
    addr = _mem_addr(addr, width)
    if width == 4:
        return _peek32(addr)
    if width == 2:
        return _peek8(addr, 0) | (_peek8(addr, 1) << 8)
    return _peek8(addr, 0)


def _mem_set(width, addr, v):
    addr = _mem_addr(addr, width)
    if width == 4:
        _poke32(addr, _w32(v))
    elif width == 2:
        _poke8(addr, 0, v & 255)
        _poke8(addr, 1, (v >> 8) & 255)
    else:
        _poke8(addr, 0, v & 255)
    return None


def _build_machine():
    class mem:
        def __init__(self, width):
            self.width = width

        def __getitem__(self, addr):
            return _mem_get(self.width, addr)

        def __setitem__(self, addr, v):
            return _mem_set(self.width, addr, v)

    g = {
        'mem8': mem(1),
        'mem16': mem(2),
        'mem32': mem(4),
    }
    return _mk_module('machine', g)


def _machine():
    m = _sysget(SR_MACHINE)
    if m is NULL:
        m = _build_machine()
        _sysset(SR_MACHINE, m)
    return m
