# Board I/O support in the firmware: the native module _io, the bridge
# window's word access. Spec: upycore/docs/mpy_io_core.md (Bridge, Hart
# software).
#
# This file and the rest of upycore/firmware/io are appended to the
# firmware only for images that use board I/O (mpy_build.io_imports: an
# import of machine, time or _io), so every other image is byte-identical
# to one built without them. A definition here may replace an earlier
# firmware one of the same name; the last definition is the one linked.

# The bridge window (mpy_iobr), as an INT address.
_IO_BASE = const(0x40000000)


def _poke32(a, w):
    # A word store: _st writes w's payload (its low 32 bits) at a. The
    # bridge ignores the tag. Not a core native: _st already does it.
    _st(a, 0, w)
    return None


def mod__io__rd(off):
    # A bridge register or state-page word, as a signed 32-bit int.
    return _peek32(_IO_BASE + off)


def mod__io__wr(off, w):
    _st(_IO_BASE + off, 0, w)
    return None


def mod__io__cpu():
    # time.ticks_cpu: the hart's cycle counter (30 bits), as on a port
    # whose ticks_cpu is the CPU's own counter.
    return _ticks()
