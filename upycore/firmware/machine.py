# machine and time: the MMIO window (upycore/docs/mpy_peripherals.md) as
# the MicroPython v1.29.0 module surface. Each module is built on its
# first import and kept in SR_MACHINE or SR_TIME, so programs that never
# import them pay nothing at boot.
#
# Register writes that belong together run with IRQ_GIE clear (_irqoff /
# _irqon), so a callback never sees half an update.
from ._abi import *

# time.ticks_* wrap at 2**30, MICROPY_PY_TIME_TICKS_PERIOD on 32-bit ports.
TICKS_PERIOD = const(1073741824)
TICKS_MAX = const(1073741823)
TICKS_HALF = const(536870912)


def _w32(v):
    # Low 32 bits of an int, as the signed word an INT payload holds.
    v = v & 0xFFFFFFFF
    if v >= 0x80000000:
        v -= 4294967296
    return v


def _irqon(state):
    _poke32(MMIO_IRQ_GIE, state & 1)
    return None


def _setbit(addr, bit, on):
    v = _peek32(addr)
    if on:
        _poke32(addr, v | (1 << bit))
    else:
        _poke32(addr, v & ~(1 << bit))
    return None


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


# The GPIO slot's callback. tab holds one entry per pin: None or
# (handler, hard, pin). Bits seen in GPIO_STATUS are cleared, then each
# pin's handler runs, lowest pin first. When this dispatch is hard
# (IRQ_ACTIVE), a soft pin's handler is queued with micropython.schedule,
# which does not allocate.
def _gpio_dispatch(tab):
    st = _peek32(MMIO_GPIO_STATUS)
    _poke32(MMIO_GPIO_STATUS, st)
    hard = _peek32(MMIO_IRQ_ACTIVE) & 1
    i = 0
    while st:
        if st & 1:
            e = tab[i]
            if e is not None:
                if hard and not e[1]:
                    _sched(e[0], e[2])
                else:
                    e[0](e[2])
        st >>= 1
        i += 1
    return None


def _timer_once(t):
    # ONE_SHOT: stop the compare before the callback, as a one-shot timer does.
    _poke32(MMIO_TIMER_COUNT, 0)
    _setbit(MMIO_IRQ_ENABLE, SRC_TIMER, False)
    t._cb(t)
    return None


def _sleep_ms(n):
    # n ticks: idle until TICKS moves, then a soft point (mp_handle_pending).
    while n > 0:
        t = _peek32(MMIO_TICKS)
        while _peek32(MMIO_TICKS) == t:
            _idle()
        _pending()
        n -= 1
    return None


def _build_machine():
    class mem:
        def __init__(self, width):
            self.width = width

        def __getitem__(self, addr):
            return _mem_get(self.width, addr)

        def __setitem__(self, addr, v):
            return _mem_set(self.width, addr, v)

    pins = [None] * 16

    class Pin:
        IN = 0
        OUT = 1
        OPEN_DRAIN = 2
        PULL_UP = 1
        PULL_DOWN = 2
        IRQ_RISING = 1
        IRQ_FALLING = 2

        def __init__(self, id, mode=-1, pull=-1, value=None):
            if not _isint(id) or id < 0 or id > 15:
                raise ValueError('invalid pin')
            self.id = id
            self.init(mode, pull, value)

        def init(self, mode=-1, pull=-1, value=None):
            if value is not None:
                self.value(value)
            if mode == 1 or mode == 2:
                _setbit(MMIO_GPIO_OE, self.id, True)
            elif mode == 0:
                _setbit(MMIO_GPIO_OE, self.id, False)
            if pull != -1:
                _setbit(MMIO_GPIO_PU, self.id, pull == 1)
                _setbit(MMIO_GPIO_PD, self.id, pull == 2)
            return None

        def value(self, v=_MISSING):
            if v is _MISSING:
                if (_peek32(MMIO_GPIO_OE) >> self.id) & 1:
                    return (_peek32(MMIO_GPIO_OUT) >> self.id) & 1
                return (_peek32(MMIO_GPIO_IN) >> self.id) & 1
            st = _irqoff()
            _setbit(MMIO_GPIO_OUT, self.id, v)
            _irqon(st)
            return None

        def __call__(self, v=_MISSING):
            return self.value(v)

        def on(self):
            return self.value(1)

        def off(self):
            return self.value(0)

        def toggle(self):
            st = _irqoff()
            _poke32(MMIO_GPIO_OUT, _peek32(MMIO_GPIO_OUT) ^ (1 << self.id))
            _irqon(st)
            return None

        def irq(self, handler=None, trigger=3, hard=False):
            st = _irqoff()
            i = self.id
            edge = _peek32(MMIO_GPIO_EDGE) & ~(3 << (2 * i))
            if handler is None:
                pins[i] = None
            else:
                pins[i] = (handler, hard, self)
                edge |= (trigger & 3) << (2 * i)
            _poke32(MMIO_GPIO_EDGE, edge)
            _poke32(MMIO_GPIO_STATUS, 1 << i)
            armed = False
            any_hard = False
            for e in pins:
                if e is not None:
                    armed = True
                    if e[1]:
                        any_hard = True
            _irq_handler(SRC_GPIO, _gpio_dispatch, pins)
            _setbit(MMIO_IRQ_HARD, SRC_GPIO, any_hard)
            _setbit(MMIO_IRQ_ENABLE, SRC_GPIO, armed)
            _irqon(st)
            return None

    class Timer:
        ONE_SHOT = 0
        PERIODIC = 1

        def __init__(self, id=-1, *args, **kw):
            if id != -1 and id != 0:
                raise ValueError('Timer does not exist')
            self._cb = None
            if args or kw:
                self.init(*args, **kw)

        def init(self, mode=1, freq=-1, period=-1, callback=None, hard=True):
            if freq > 0:
                period = 1000 // freq
                if period < 1:
                    period = 1
            if period < 0:
                raise ValueError('period required')
            st = _irqoff()
            _poke32(MMIO_TIMER_COUNT, 0)
            self._cb = callback
            if callback is None:
                _irq_handler(SRC_TIMER, NULL, NULL)
            elif mode == 0:
                _irq_handler(SRC_TIMER, _timer_once, self)
            else:
                _irq_handler(SRC_TIMER, callback, self)
            _poke32(MMIO_IRQ_STATUS, 1 << SRC_TIMER)
            _setbit(MMIO_IRQ_HARD, SRC_TIMER, hard)
            _setbit(MMIO_IRQ_ENABLE, SRC_TIMER, callback is not None)
            _poke32(MMIO_TIMER_COUNT, period)
            _irqon(st)
            return None

        def deinit(self):
            st = _irqoff()
            _poke32(MMIO_TIMER_COUNT, 0)
            _setbit(MMIO_IRQ_ENABLE, SRC_TIMER, False)
            _irq_handler(SRC_TIMER, NULL, NULL)
            self._cb = None
            _irqon(st)
            return None

    class UART:
        IRQ_RX = 1

        def __init__(self, id, baudrate=None, bits=8, parity=None, stop=1, **kw):
            if id != 0:
                raise ValueError('UART does not exist')
            self.init(baudrate, bits, parity, stop)

        def init(self, baudrate=None, bits=8, parity=None, stop=1, **kw):
            if baudrate is not None:
                if baudrate <= 0:
                    raise ValueError('bad baudrate')
                _poke32(MMIO_UART_BAUD, _peek32(MMIO_SYS_FREQ) // baudrate)
            return None

        def deinit(self):
            return None

        def any(self):
            return _peek32(MMIO_UART_STATUS) & 255

        def write(self, buf):
            if _isstr(buf):
                b = buf
            else:
                b = _as_bytes(buf)
            n = _slen(b)
            i = 0
            while i < n:
                if _peek32(MMIO_UART_BAUD) & 65535:
                    while _peek32(MMIO_UART_STATUS) & 262144:
                        pass
                _poke32(MMIO_UART_TX, _byte(b, i))
                i += 1
            return n

        def read(self, nbytes=-1):
            n = _peek32(MMIO_UART_STATUS) & 255
            if nbytes >= 0 and nbytes < n:
                n = nbytes
            if n == 0:
                return None
            b = _strnew(n, TAG_BYTES)
            d = _data(b)
            i = 0
            while i < n:
                _poke8(d, i, _peek32(MMIO_UART_RX) & 255)
                i += 1
            return _strfin(b)

        def readinto(self, buf, nbytes=-1):
            n = _peek32(MMIO_UART_STATUS) & 255
            if nbytes < 0 or nbytes > len(buf):
                nbytes = len(buf)
            if nbytes < n:
                n = nbytes
            if n == 0:
                return None
            i = 0
            while i < n:
                buf[i] = _peek32(MMIO_UART_RX) & 255
                i += 1
            return n

        def irq(self, handler=None, trigger=1, hard=False):
            st = _irqoff()
            if handler is None:
                _irq_handler(SRC_UART, NULL, NULL)
            else:
                _irq_handler(SRC_UART, handler, self)
            _setbit(MMIO_IRQ_HARD, SRC_UART, hard)
            _setbit(MMIO_IRQ_ENABLE, SRC_UART, handler is not None)
            _irqon(st)
            return None

    def disable_irq():
        return _irqoff()

    def enable_irq(state=1):
        return _irqon(state)

    def idle():
        return _idle()

    def freq():
        return _peek32(MMIO_SYS_FREQ)

    g = {
        'mem8': mem(1),
        'mem16': mem(2),
        'mem32': mem(4),
        'Pin': Pin,
        'Timer': Timer,
        'UART': UART,
        'disable_irq': disable_irq,
        'enable_irq': enable_irq,
        'idle': idle,
        'freq': freq,
    }
    return _mk_module('machine', g)


def _machine():
    m = _sysget(SR_MACHINE)
    if m is NULL:
        m = _build_machine()
        _sysset(SR_MACHINE, m)
    return m


def _ticks_ms():
    return _peek32(MMIO_TICKS) & TICKS_MAX


def _ticks_us():
    return (_peek32(MMIO_TICKS) * 1000) & TICKS_MAX


def _ticks_cpu():
    return _ticks() & TICKS_MAX


def _ticks_diff(a, b):
    return ((a - b + TICKS_HALF) & TICKS_MAX) - TICKS_HALF


def _ticks_add(t, d):
    return (t + d) & TICKS_MAX


def _time_sleep(s):
    return _sleep_ms(int(s * 1000))


def _time_sleep_us(n):
    return _sleep_ms((n + 999) // 1000)


def _build_time():
    return _mk_module('time', {
        'ticks_ms': _ticks_ms,
        'ticks_us': _ticks_us,
        'ticks_cpu': _ticks_cpu,
        'ticks_diff': _ticks_diff,
        'ticks_add': _ticks_add,
        'sleep': _time_sleep,
        'sleep_ms': _sleep_ms,
        'sleep_us': _time_sleep_us,
    })


def _time():
    m = _sysget(SR_TIME)
    if m is NULL:
        m = _build_time()
        _sysset(SR_TIME, m)
    return m
