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


# ---- the remaining peripherals (phase 4) ----

_io_hz = []


def _iohz():
    # io_clk in Hz, from the I/O core (SYS FREQ), once.
    if not _io_hz:
        _io_hz.append(_io.req(0x01020000))
    return _io_hz[0]


def _pin_id(p):
    return p._id if isinstance(p, Pin) else p


def _func(pin, f):
    _cmd(0x14000000 | pin | (f << 8))


def _words(buf):
    # Bytes, three to a word, byte 0 in bits 7:0.
    out = []
    n = len(buf)
    i = 0
    while i < n:
        w = buf[i]
        if i + 1 < n:
            w |= buf[i + 1] << 8
        if i + 2 < n:
            w |= buf[i + 2] << 16
        out.append(w)
        i += 3
    return out


def _unwords(ws, n):
    out = bytearray(n)
    for i in range(n):
        out[i] = (ws[i // 3] >> (8 * (i % 3))) & 255
    return out


class PWM:
    # machine.PWM (extmod/machine_pwm.c): four channels on one counter, so,
    # as on an rp2 slice, the channels share the frequency. Channel pin % 4;
    # the pad's function is that channel.
    def __init__(self, dest, *, freq=0, duty_u16=-1, duty_ns=-1, invert=False):
        _need()
        self._pin = _pin_id(dest)
        self._ch = self._pin % 4
        self._duty = 0
        self._top = 0
        self.init(freq=freq, duty_u16=duty_u16, duty_ns=duty_ns)

    def init(self, *, freq=0, duty_u16=-1, duty_ns=-1, invert=False):
        if freq > 0:
            self.freq(freq)
        if duty_u16 >= 0:
            self.duty_u16(duty_u16)
        elif duty_ns >= 0:
            self.duty_ns(duty_ns)
        _func(self._pin, 1 + self._ch)
        _PWM_ON[0] |= 1 << self._ch
        _cmd(0x42000000 | _PWM_ON[0])

    def deinit(self):
        _PWM_ON[0] &= ~(1 << self._ch)
        _cmd(0x42000000 | _PWM_ON[0])
        _func(self._pin, 0)

    def freq(self, *f):
        if not f:
            return _PWM_CFG[0]
        counts = max(1, _iohz() // f[0])
        presc = (counts - 1) // 65536
        top = counts // (presc + 1) - 1
        _PWM_CFG[0] = _iohz() // ((top + 1) * (presc + 1))
        _PWM_CFG[1] = top
        _PWM_CFG[2] = presc
        _io.cmd2(0x40000000, (presc << 16) | top)
        self._top = top
        self.duty_u16(self._duty)

    def duty_u16(self, *d):
        if not d:
            return self._duty
        self._duty = d[0] & 0xFFFF
        top = _PWM_CFG[1]
        _io.cmd2(0x41000000 | self._ch, self._duty * (top + 1) // 65535)

    def duty_ns(self, *d):
        if not d:
            return self._duty * 1000000000 // (65535 * max(1, _PWM_CFG[0]))
        period_ns = 1000000000 // max(1, _PWM_CFG[0])
        self.duty_u16(min(65535, d[0] * 65535 // period_ns))

    def __repr__(self):
        return "<PWM pin=%d freq=%d duty_u16=%d>" % (self._pin, _PWM_CFG[0], self._duty)


_PWM_ON = [0]
_PWM_CFG = [0, 65535, 0]     # frequency, top, prescaler


class SPI:
    # machine.SPI (extmod/machine_spi.c): the I/O core's SPI controller,
    # modes 0-3, 8 bits, MSB first; pads 10 SCK, 11 MOSI, 12 MISO by
    # default. A transfer of up to 64 bytes is one command.
    MSB = 0
    LSB = 1

    def __init__(self, id=0, baudrate=1000000, *, polarity=0, phase=0, bits=8, firstbit=0,
                 sck=None, mosi=None, miso=None):
        if id != 0:
            raise ValueError("SPI(%d) doesn't exist" % id)
        _need()
        self.init(baudrate, polarity=polarity, phase=phase, bits=bits, firstbit=firstbit,
                  sck=sck, mosi=mosi, miso=miso)

    def init(self, baudrate=1000000, *, polarity=0, phase=0, bits=8, firstbit=0,
             sck=None, mosi=None, miso=None):
        if bits != 8 or firstbit != 0:
            raise ValueError("only 8 bits, MSB first")
        self._pins = (_pin_id(sck) if sck is not None else 10, _pin_id(mosi) if mosi is not None else 11,
                      _pin_id(miso) if miso is not None else 12)
        _func(self._pins[0], 5)
        _func(self._pins[1], 6)
        _func(self._pins[2], 7)
        hz = _iohz()
        div = max(0, (hz + 2 * baudrate - 1) // (2 * baudrate) - 1)
        self._baud = hz // (2 * (div + 1))
        _io.cmd2(0x50000000 | (polarity & 1) | ((phase & 1) << 1), div)

    def deinit(self):
        _cmd(0x52000000)
        for p in self._pins:
            _func(p, 0)

    def _xfer(self, out, want):
        res = bytearray()
        i = 0
        n = len(out)
        while i < n:
            k = min(63, n - i)
            chunk = out[i:i + k]
            ws = _io.xfer([0x51000000 | k | (0x100 if want else 0)] + _words(chunk),
                          (k + 2) // 3 if want else 0)
            if want:
                res.extend(_unwords(ws, k))
            i += k
        return res

    def write(self, buf):
        self._xfer(buf, False)
        return None

    def read(self, nbytes, write=0):
        return bytes(self._xfer(bytes([write]) * nbytes, True))

    def readinto(self, buf, write=0):
        r = self._xfer(bytes([write]) * len(buf), True)
        for i in range(len(buf)):
            buf[i] = r[i]
        return None

    def write_readinto(self, wbuf, rbuf):
        r = self._xfer(wbuf, True)
        for i in range(len(rbuf)):
            rbuf[i] = r[i]
        return None


class I2C:
    # machine.I2C (extmod/machine_i2c.c): the I/O core's I2C controller,
    # pads 14 SCL and 15 SDA by default. A NACKed address raises
    # OSError(ENODEV), a stretch longer than timeout (µs) OSError(ETIMEDOUT).
    def __init__(self, id=0, *, scl=None, sda=None, freq=400000, timeout=50000):
        if id != 0:
            raise ValueError("I2C(%d) doesn't exist" % id)
        _need()
        self.init(scl=scl, sda=sda, freq=freq, timeout=timeout)

    def init(self, *, scl=None, sda=None, freq=400000, timeout=50000):
        self._pins = (_pin_id(scl) if scl is not None else 14, _pin_id(sda) if sda is not None else 15)
        _func(self._pins[0], 8)
        _func(self._pins[1], 9)
        hz = _iohz()
        div = min(0xFFFF, max(0, hz // (4 * freq) - 1))
        clocks = min(0xFFFFFFFF, timeout * (hz // 1000000))
        _io.xfer([0x60000000, div, clocks], 0)

    def deinit(self):
        _cmd(0x62000000)
        for p in self._pins:
            _func(p, 0)

    def _check(self, st):
        if st == -19:
            raise OSError(19)
        if st == -110:
            raise OSError(110)

    def scan(self):
        out = []
        for a in range(0x08, 0x78):
            if _io.xfer([0x61030000 | a], 1)[0] == 0:
                out.append(a)
        return out

    def writeto(self, addr, buf, stop=True):
        n = len(buf)
        r = _io.xfer([0x61000000 | (addr & 0x7F) | (n << 8) | 0x10000 | (0x20000 if stop else 0)]
                     + _words(buf), 1)[0]
        self._check(r)
        return n - r

    def readfrom_into(self, addr, buf, stop=True):
        n = len(buf)
        r = _io.xfer([0x61000080 | (addr & 0x7F) | (n << 8) | 0x10000 | 0x40000 | (0x20000 if stop else 0)],
                     1 + (n + 2) // 3)
        self._check(r[0])
        data = _unwords(r[1:], n)
        for i in range(n):
            buf[i] = data[i]
        return None

    def readfrom(self, addr, nbytes, stop=True):
        buf = bytearray(nbytes)
        self.readfrom_into(addr, buf, stop)
        return bytes(buf)

    def _memaddr(self, memaddr, addrsize):
        return bytes([(memaddr >> (8 * i)) & 255 for i in range(addrsize // 8 - 1, -1, -1)])

    def writeto_mem(self, addr, memaddr, buf, *, addrsize=8):
        self.writeto(addr, self._memaddr(memaddr, addrsize) + bytes(buf))
        return None

    def readfrom_mem_into(self, addr, memaddr, buf, *, addrsize=8):
        self.writeto(addr, self._memaddr(memaddr, addrsize), False)
        self.readfrom_into(addr, buf)
        return None

    def readfrom_mem(self, addr, memaddr, nbytes, *, addrsize=8):
        buf = bytearray(nbytes)
        self.readfrom_mem_into(addr, memaddr, buf, addrsize=addrsize)
        return bytes(buf)


class ADC:
    # machine.ADC (extmod/machine_adc.c): a channel number or a Pin (its id
    # is the channel); read_u16 is the 12-bit code left-aligned.
    def __init__(self, id):
        _need()
        self._ch = _pin_id(id) & 15

    def read_u16(self):
        return _io.req(0x70000000 | self._ch)

    def __repr__(self):
        return "<ADC channel=%d>" % self._ch


class WDT:
    # machine.WDT (extmod/machine_wdt.c): the I/O core's watchdog, a tick a
    # millisecond. It cannot be stopped; when it runs out the hart domain
    # resets with reset_cause() WDT_RESET.
    def __init__(self, id=0, timeout=5000):
        if id != 0:
            raise ValueError("WDT(%d) doesn't exist" % id)
        _need()
        # Channel 0x80's words have bit 31 set: written as the signed words
        # they are, since _st stores a small int's payload and 0x80000000
        # is not one.
        _io.cmd2(-0x80000000, timeout)

    def feed(self):
        _cmd(-0x7F000000)


PWRON_RESET = 1
HARD_RESET = 2
WDT_RESET = 3
DEEPSLEEP_RESET = 4
SOFT_RESET = 5


def reset_cause():
    return _rd(0x02C)


def reset():
    _io.reset(0)


def soft_reset():
    _io.reset(1)


def unique_id():
    hi, lo = _io.xfer([0x01030000], 2)
    return bytes([(hi >> 24) & 255, (hi >> 16) & 255, (hi >> 8) & 255, hi & 255,
                  (lo >> 24) & 255, (lo >> 16) & 255, (lo >> 8) & 255, lo & 255])
