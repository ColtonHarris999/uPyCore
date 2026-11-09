# machine, MicroPython v1.29.0 signatures, on the I/O core. Frozen only into
# programs that import it (mpy_build.RUNTIME_MODULES). Spec:
# upycore/docs/mpy_io_core.md (machine, Commands, State page).
#
# The bridge window is reached through the firmware's _io module: _io.rd(off)
# and _io.wr(off, w) are one word load or store at 0x4000_0000 + off.
# Commands go to the I/O core through CMD; its answers come back in RSP;
# levels and counters are read from the state page. The numbers match
# iocore/sw/fw/proto.h.
import _io

_rd = _io.rd
_wr = _io.wr

_BASE = 0x40000000
_END = 0x40001000
_CMD = 0x000
_RSP = 0x004
_STATUS = 0x008
_IOC_CTRL = 0x01C
_PAGE = 0x800

_PG_PIN_IN = 1
_PG_UART0 = 6
_PG_SEQ = 7
_PG_TIMER0 = 8

_ENODEV = 19


def _need():
    # The I/O core runs only when the boot stream carried its firmware.
    if not (_rd(_IOC_CTRL) & 1):
        raise OSError(_ENODEV)


_sent = [0]


def _cmd(w):
    _wr(_CMD, w)
    _sent[0] += 1


def _rsp():
    while _rd(_STATUS) >= 0:      # bit 31: RSP not empty
        pass
    return _rd(_RSP)


def _fence():
    # Wait until the I/O core has finished every command sent so far, so a
    # state-page read sees their effects.
    n = _sent[0] & 0xFFFFFFFF
    while (_rd(_PAGE + 4 * _PG_SEQ) & 0xFFFFFFFF) != n:
        pass


def _page(i):
    return _rd(_PAGE + 4 * i)


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
        return _rd(self._addr(a))

    def __setitem__(self, a, v):
        _wr(self._addr(a), v)


mem32 = mem(4)

_NPINS = 16


class Pin:
    # machine.Pin (extmod/machine_pin.c and the rp2 port's machine_pin.c):
    # the pins of the I/O core's GPIO block, ids 0-15.
    IN = 0
    OUT = 1
    OPEN_DRAIN = 2
    PULL_UP = 1
    PULL_DOWN = 2
    IRQ_RISING = 1
    IRQ_FALLING = 2

    def __init__(self, id, mode=-1, pull=-1, *, value=None):
        if isinstance(id, Pin):
            id = id._id
        if not isinstance(id, int) or id < 0 or id >= _NPINS:
            raise ValueError("invalid pin")
        _need()
        self._id = id
        self._mode = 0
        self._pull = 0
        self.init(mode, pull, value=value)

    def init(self, mode=-1, pull=-1, *, value=None):
        if mode != -1:
            if mode not in (0, 1, 2):
                raise ValueError("invalid pin mode: %d" % mode)
            self._mode = mode
        if pull != -1:
            if pull is None:
                pull = 0
            if pull not in (0, 1, 2):
                raise ValueError("invalid pull: %d" % pull)
            self._pull = pull
        w = 0x10000000 | self._id | (self._mode << 5) | (self._pull << 8)
        if value is not None:
            w |= 0x400 | (0x800 if value else 0)
        _cmd(w)
        return None

    def value(self, *v):
        if v:
            _cmd(0x11000000 | self._id | (0x100 if v[0] else 0))
            return None
        _fence()
        return (_page(_PG_PIN_IN) >> self._id) & 1

    def __call__(self, *v):
        return self.value(*v)

    def on(self):
        _cmd(0x11000100 | self._id)

    def off(self):
        _cmd(0x11000000 | self._id)

    def high(self):
        _cmd(0x11000100 | self._id)

    def low(self):
        _cmd(0x11000000 | self._id)

    def toggle(self):
        _cmd(0x12000000 | self._id)

    def mode(self, *m):
        if m:
            self.init(m[0])
            return None
        return self._mode

    def pull(self, *p):
        if p:
            self.init(-1, p[0])
            return None
        return self._pull

    def __repr__(self):
        return "Pin(%d, mode=%s)" % (self._id, ("IN", "OUT", "OPEN_DRAIN")[self._mode])


class UART:
    # machine.UART (extmod/machine_uart.c): UART0 of the I/O core, 8N1.
    # Bytes go through CMD three to a word and come back through RSP; any()
    # reads the state page. The I/O core buffers 256 received bytes.
    def __init__(self, id, baudrate=115200, bits=8, parity=None, stop=1, **kw):
        if id != 0:
            raise ValueError("UART(%d) doesn't exist" % id)
        _need()
        self._id = id
        self._timeout = 0
        self.init(baudrate, bits, parity, stop, **kw)

    def init(self, baudrate=115200, bits=8, parity=None, stop=1, *, timeout=0, timeout_char=0,
             tx=None, rx=None, txbuf=None, rxbuf=None):
        if bits != 8 or parity is not None or stop != 1:
            raise ValueError("only 8N1 is supported")
        self._timeout = timeout
        _cmd(0x20000000 | self._id)
        _cmd(baudrate)
        self._baud = _rsp()
        return None

    def deinit(self):
        _cmd(0x29000000 | self._id)

    def any(self):
        _fence()
        return _page(_PG_UART0) & 0xFFFF

    def write(self, buf):
        if isinstance(buf, str):
            buf = buf.encode()
        n = len(buf)
        i = 0
        while i + 3 <= n:
            _cmd(0x23000000 | buf[i] | (buf[i + 1] << 8) | (buf[i + 2] << 16))
            i += 3
        if n - i == 2:
            _cmd(0x22000000 | buf[i] | (buf[i + 1] << 8))
        elif n - i == 1:
            _cmd(0x21000000 | buf[i])
        return n

    def _take(self, n):
        out = bytearray()
        while n > 0:
            k = n if n < 255 else 255
            _cmd(0x28000000 | k)
            got = _rsp()
            j = 0
            while j < got:
                w = _rsp()
                out.append(w & 0xFF)
                if j + 1 < got:
                    out.append((w >> 8) & 0xFF)
                if j + 2 < got:
                    out.append((w >> 16) & 0xFF)
                j += 3
            if got == 0:
                break
            n -= got
        return out

    def _wait(self, n):
        # Wait up to timeout ms for n bytes (timeout 0: what is there).
        if self._timeout <= 0:
            return
        import time
        t0 = time.ticks_ms()
        while self.any() < n and time.ticks_diff(time.ticks_ms(), t0) < self._timeout:
            pass

    def read(self, nbytes=-1):
        if nbytes is None or nbytes < 0:
            self._wait(1)
            n = self.any()
        else:
            self._wait(nbytes)
            n = min(nbytes, self.any())
        if n == 0:
            return None
        return bytes(self._take(n))

    def readinto(self, buf, nbytes=-1):
        if nbytes < 0:
            nbytes = len(buf)
        self._wait(nbytes)
        data = self._take(min(nbytes, self.any()))
        if not data:
            return None
        for i in range(len(data)):
            buf[i] = data[i]
        return len(data)

    def readline(self):
        out = bytearray()
        while True:
            self._wait(1)
            if self.any() == 0:
                break
            b = self._take(1)
            out.extend(b)
            if b[0] == 10:
                break
        return bytes(out) if out else None

    def txdone(self):
        _fence()
        return not (_page(_PG_UART0) & 0x80000000)

    def flush(self):
        while not self.txdone():
            pass

    def __repr__(self):
        return "UART(%d, baudrate=%d, bits=8, parity=None, stop=1)" % (self._id, self._baud)


class Timer:
    # machine.Timer (extmod/machine_timer.c signatures): four software timers
    # in the I/O core on its microsecond counter. Callbacks arrive with the
    # events of phase 3; until then a timer's expirations are counted in the
    # state page (Timer._count).
    ONE_SHOT = 0
    PERIODIC = 1

    def __init__(self, id=-1, **kw):
        if id == -1:
            id = 0
        if id < 0 or id > 3:
            raise ValueError("Timer(%d) doesn't exist" % id)
        _need()
        self._id = id
        self._cb = None
        if kw:
            self.init(**kw)

    def init(self, *, mode=1, freq=-1, period=-1, callback=None, tick_hz=1000, hard=True):
        if freq > 0:
            us = int(1000000 / freq)
        elif period >= 0:
            us = int(period * 1000000 // tick_hz)
        else:
            us = 1000000
        self._cb = callback
        _cmd(0x30000000 | self._id | (4 if mode == 1 else 0))
        _cmd(us)

    def deinit(self):
        _cmd(0x31000000 | self._id)

    def _count(self):
        _fence()
        return _page(_PG_TIMER0 + self._id)


def freq():
    return 100000000


def idle():
    return None
