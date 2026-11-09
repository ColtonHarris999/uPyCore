# machine, MicroPython v1.29.0 signatures, on the I/O core. Frozen only into
# programs that import it (mpy_build.RUNTIME_MODULES). Spec:
# upycore/docs/mpy_io_core.md (machine, Commands, State page, Events).
#
# The bridge is reached through the firmware's _io module. Its functions
# are firmware: a command and its answer are one call, so no callback can
# run in the middle of one (a soft point never falls inside firmware).
# _io.rd(off) and _io.wr(off, w) are one word at 0x4000_0000 + off; _io.cmd
# sends a command word, _io.req a command word and returns its answer,
# _io.page(i) reads a state-page word once every command sent has run.
# The numbers match iocore/sw/fw/proto.h.
import _io

_rd = _io.rd
_wr = _io.wr
_cmd = _io.cmd
_page = _io.page

_BASE = 0x40000000
_END = 0x40001000
_IOC_CTRL = 0x01C

_PG_PIN_IN = 1
_PG_PIN_FLAGS = 2
_PG_UART0 = 6
_PG_TIMER0 = 8
_PG_PIN_CNT = 12
_PG_UART0_EV = 16

_EV_UART0 = 4
_EV_TIMER = 8
_EV_PIN = 16

_ENODEV = 19
_HZ = 100000000          # the hart's clock (freq())


def _need():
    # The I/O core runs only when the boot stream carried its firmware.
    if not (_rd(_IOC_CTRL) & 1):
        raise OSError(_ENODEV)


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


class _IRQ:
    # The irq object Pin.irq() and UART.irq() return (shared/runtime/mpirq.c):
    # flags() is the cause of the last event, trigger() the armed triggers.
    def __init__(self, owner):
        self._owner = owner

    def flags(self):
        return self._owner._irq_flags()

    def trigger(self, *t):
        old = self._owner._irq_trigger
        if t:
            self._owner._irq_set_trigger(t[0])
        return old

    def __call__(self):
        h = self._owner._irq_entry
        if h is not None and h[0] is not None:
            h[0](self._owner)


class Pin:
    # machine.Pin (ports/rp2/machine_pin.c): the pins of the I/O core's GPIO
    # block, ids 0-15.
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
        self._irq_entry = None
        self._irq_trigger = 0
        self._irq_obj = None
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

    def irq(self, handler=None, trigger=3, hard=False):
        # Pin.irq (ports/rp2/machine_pin.c): the edge is armed on the I/O
        # core, which counts edges and raises PIN; a soft handler is
        # scheduled, a hard one runs at the next soft point with the heap
        # locked (decision D2). Several edges before the handler runs give
        # one call, as several schedules of a pending callback do.
        if self._irq_obj is None:
            self._irq_obj = _IRQ(self)
        if handler is None and trigger == 3 and not hard and self._irq_entry is None:
            return self._irq_obj
        self._irq_trigger = trigger & 3
        cnt = (_page(_PG_PIN_CNT + self._id // 4) >> (8 * (self._id % 4))) & 255
        if handler is None:
            self._irq_entry = None
            _io.set_handler('pin', self._id, None)
            _cmd(0x13000000 | self._id)
        else:
            self._irq_entry = [handler, self, self._irq_trigger, hard, cnt]
            _io.set_handler('pin', self._id, self._irq_entry)
            _io.evt_enable(_EV_PIN, True)
            _cmd(0x13000000 | self._id | (self._irq_trigger << 8))
        return self._irq_obj

    def _irq_flags(self):
        return (_page(_PG_PIN_FLAGS) >> (2 * self._id)) & 3

    def _irq_set_trigger(self, t):
        self._irq_trigger = t & 3
        _cmd(0x13000000 | self._id | (self._irq_trigger << 8))

    def __repr__(self):
        return "Pin(%d, mode=%s)" % (self._id, ("IN", "OUT", "OPEN_DRAIN")[self._mode])


class UART:
    # machine.UART (extmod/machine_uart.c): UART0 of the I/O core, 8N1.
    # Bytes go through CMD three to a word and come back through RSP; any()
    # reads the state page. The I/O core buffers 256 received bytes. The
    # IRQ_* values are rp2's.
    IRQ_TXIDLE = 32
    IRQ_RXIDLE = 64

    def __init__(self, id, baudrate=115200, bits=8, parity=None, stop=1, **kw):
        if id != 0:
            raise ValueError("UART(%d) doesn't exist" % id)
        _need()
        self._id = id
        self._timeout = 0
        self._irq_entry = None
        self._irq_trigger = 0
        self._irq_obj = None
        self.init(baudrate, bits, parity, stop, **kw)

    def init(self, baudrate=115200, bits=8, parity=None, stop=1, *, timeout=0, timeout_char=0,
             tx=None, rx=None, txbuf=None, rxbuf=None):
        if bits != 8 or parity is not None or stop != 1:
            raise ValueError("only 8N1 is supported")
        self._timeout = timeout
        self._baud = _io.req2(0x20000000 | self._id, baudrate)
        return None

    def deinit(self):
        _cmd(0x29000000 | self._id)

    def any(self):
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
        out = b""
        while n > 0:
            got = _io.uart_rx(n if n < 255 else 255)
            if not got:
                break
            out += got
            n -= len(got)
        return out

    def _wait(self, n):
        # Wait up to timeout ms for n bytes (timeout 0: what is there).
        if self._timeout <= 0:
            return
        import time
        t0 = time.ticks_ms()
        while self.any() < n and time.ticks_diff(time.ticks_ms(), t0) < self._timeout:
            idle()

    def read(self, nbytes=-1):
        if nbytes is None or nbytes < 0:
            self._wait(1)
            n = self.any()
        else:
            self._wait(nbytes)
            n = min(nbytes, self.any())
        if n == 0:
            return None
        return self._take(n)

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
        out = b""
        while True:
            self._wait(1)
            if self.any() == 0:
                break
            b = self._take(1)
            out += b
            if b[0] == 10:
                break
        return out if out else None

    def txdone(self):
        return not (_page(_PG_UART0) & 0x80000000)

    def flush(self):
        while not self.txdone():
            pass

    def irq(self, handler=None, trigger=0, hard=False):
        # UART.irq (extmod/machine_uart.c): IRQ_RXIDLE after received bytes
        # and two character times quiet, IRQ_TXIDLE once sending is done.
        if self._irq_obj is None:
            self._irq_obj = _IRQ(self)
        self._irq_trigger = trigger
        seen = _page(_PG_UART0_EV) & 0xFFFF
        if handler is None or trigger == 0:
            self._irq_entry = None
            _io.set_handler('uart', 0, None)
            _cmd(0x2A000000)
        else:
            self._irq_entry = [handler, self, trigger, hard, seen]
            _io.set_handler('uart', 0, self._irq_entry)
            _io.evt_enable(_EV_UART0, True)
            _cmd(0x2A000000 | (trigger & 0xFFFF))
        return self._irq_obj

    def _irq_flags(self):
        return (_page(_PG_UART0_EV) >> 16) & 0xFF

    def _irq_set_trigger(self, t):
        self.irq(self._irq_entry[0] if self._irq_entry else None, t)

    def __repr__(self):
        return "UART(%d, baudrate=%d, bits=8, parity=None, stop=1)" % (self._id, self._baud)


class Timer:
    # machine.Timer (extmod/machine_timer.c): four software timers in the
    # I/O core on its microsecond counter. A callback is scheduled (soft)
    # or runs at the next soft point with the heap locked (hard, the
    # default, decision D2) once per expiration, at most four at a time.
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
        if callback is not None:
            seen = _page(_PG_TIMER0 + self._id)
            _io.set_handler('tmr', self._id, [callback, self, hard, seen])
            _io.evt_enable(_EV_TIMER, True)
        else:
            _io.set_handler('tmr', self._id, None)
        _io.cmd2(0x30000000 | self._id | (4 if mode == 1 else 0) | (8 if callback is not None else 0), us)

    def deinit(self):
        _cmd(0x31000000 | self._id)
        _io.set_handler('tmr', self._id, None)

    def _count(self):
        return _page(_PG_TIMER0 + self._id)


def disable_irq():
    # Events wait until enable_irq (EVT_MASK bit 1); returns the state.
    return _io.disable_irq()


def enable_irq(state=True):
    _io.enable_irq(state)


def freq():
    return _HZ


def idle():
    # Wait for an event, or 1 ms (_wfe: the core waits in one state).
    _io.wfe(_HZ // 1000)
    return None
