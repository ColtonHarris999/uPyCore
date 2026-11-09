# time, MicroPython v1.29.0 (extmod/modtime.c), on the I/O core's timer.
# Frozen only into programs that import it. ticks_ms and ticks_us read the
# state page words that mpy_iobr fills from the island timer (gray-coded
# across the clock crossing, so a read is an exact count); ticks_cpu is the
# hart's cycle counter. The period is 2**30, as on a port with 31-bit small
# ints. Spec: upycore/docs/mpy_io_core.md (time).
import _io

_rd = _io.rd
_MS = 0x800 + 4 * 3
_US = 0x800 + 4 * 4
_PERIOD = 0x40000000
_MASK = 0x3FFFFFFF
_HALF = 0x20000000


def _need():
    if not (_rd(0x01C) & 1):
        raise OSError(19)


def ticks_ms():
    return _rd(_MS) & _MASK


def ticks_us():
    return _rd(_US) & _MASK


def ticks_cpu():
    return _io.cpu() & _MASK


def ticks_add(ticks, delta):
    if delta + _HALF - 1 >= _PERIOD - 1 or delta + _HALF - 1 < 0:
        raise OverflowError("ticks interval overflow")
    return (ticks + delta) & _MASK


def ticks_diff(end, start):
    return ((end - start + _HALF) & _MASK) - _HALF


def sleep_ms(ms):
    # On the microsecond count, so the sleep is never shorter than asked
    # (a millisecond edge can be up to 1 ms away).
    _need()
    if ms <= 0:
        return None
    us = ms * 1000
    t = _rd(_US)
    while ((_rd(_US) - t) & 0xFFFFFFFF) < us:
        pass
    return None


def sleep_us(us):
    _need()
    if us <= 0:
        return None
    t = _rd(_US)
    while ((_rd(_US) - t) & 0xFFFFFFFF) < us:
        pass
    return None


def sleep(s):
    if isinstance(s, float):
        return sleep_us(int(s * 1000000))
    return sleep_ms(s * 1000)


def time():
    # Seconds since the I/O core started (there is no RTC).
    return (_rd(_MS) & 0xFFFFFFFF) // 1000


def time_ns():
    return (_rd(_US) & 0xFFFFFFFF) * 1000
