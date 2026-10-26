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


def _pinmux(pin, fn):
    # Four bits per pad; pads 0-7 in PINMUX0, 8-15 in PINMUX1.
    addr = MMIO_PINMUX0 + 4 * (pin >> 3)
    sh = 4 * (pin & 7)
    _poke32(addr, _w32((_peek32(addr) & ~(15 << sh)) | (fn << sh)))
    return None


# PWM: four channels on one counter, so freq() is shared by every channel.
# The channel of a pin is its id mod 4. _pwm_duty keeps each channel's
# duty_u16, so a new frequency keeps the duty cycles.
def _pwm_set_duty(ch, d):
    top = _peek32(MMIO_PWM_TOP)
    _poke32(MMIO_PWM_DUTY0 + 4 * ch, d * (top + 1) // 65535)
    return None


def _pwm_set_freq(f, duties):
    hz = _peek32(MMIO_SYS_FREQ)
    if f <= 0 or f > hz:
        raise ValueError('freq out of range')
    counts = hz // f
    presc = (counts - 1) >> 16
    top = counts // (presc + 1) - 1
    _poke32(MMIO_PWM_PRESC, presc)
    _poke32(MMIO_PWM_TOP, top)
    ch = 0
    while ch < 4:
        _pwm_set_duty(ch, duties[ch])
        ch += 1
    return None


# SPI: up to one FIFO of bytes in flight, then drain what came back.
# rbuf is a bytearray or None; out supplies the byte to send at i.
SPI_FIFO = const(8)


def _spi_xfer(wbuf, wconst, rbuf, n):
    i = 0
    while i < n:
        k = n - i
        if k > SPI_FIFO:
            k = SPI_FIFO
        j = 0
        while j < k:
            _poke32(MMIO_SPI_DATA, wconst if wbuf is None else _byte(wbuf, i + j))
            j += 1
        while ((_peek32(MMIO_SPI_STATUS) >> 8) & 31) < k:
            pass
        j = 0
        while j < k:
            v = _peek32(MMIO_SPI_DATA) & 255
            if rbuf is not None:
                rbuf[i + j] = v
            j += 1
        i += k
    return None


# I2C: one command at a time; the block waits out a stretch up to
# I2C_TIMEOUT, then releases the bus and sets the timeout bit.
I2C_START = const(1)
I2C_STOP = const(2)
I2C_WRITE = const(3)
I2C_READ = const(4)
ENODEV = const(19)
ETIMEDOUT = const(110)


def _i2c_cmd(c):
    _poke32(MMIO_I2C_CMD, c)
    st = _peek32(MMIO_I2C_STATUS)
    while st & 1:
        st = _peek32(MMIO_I2C_STATUS)
    if st & 4:
        raise OSError(ETIMEDOUT)
    return st


# Bytes of b sent after START; the count the target ACKed. A NACKed
# address is ENODEV. STOP when stop is set or on any error.
def _i2c_write(addr_byte, b, n, stop):
    _i2c_cmd(I2C_START)
    if _i2c_cmd(I2C_WRITE | (addr_byte << 8)) & 2:
        _i2c_cmd(I2C_STOP)
        raise OSError(ENODEV)
    acks = 0
    while acks < n:
        if _i2c_cmd(I2C_WRITE | (_byte(b, acks) << 8)) & 2:
            stop = True
            break
        acks += 1
    if stop:
        _i2c_cmd(I2C_STOP)
    return acks


def _i2c_read(addr, buf, stop):
    _i2c_cmd(I2C_START)
    if _i2c_cmd(I2C_WRITE | (((addr << 1) | 1) << 8)) & 2:
        _i2c_cmd(I2C_STOP)
        raise OSError(ENODEV)
    n = len(buf)
    i = 0
    while i < n:
        last = 1 if i == n - 1 else 0
        buf[i] = (_i2c_cmd(I2C_READ | (last << 16)) >> 8) & 255
        i += 1
    if stop:
        _i2c_cmd(I2C_STOP)
    return None


def _i2c_memaddr(memaddr, addrsize):
    out = bytearray(addrsize // 8)
    i = len(out)
    while i > 0:
        i -= 1
        out[i] = memaddr & 255
        memaddr >>= 8
    return out


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

    pwm_duty = [0, 0, 0, 0]

    class PWM:
        def __init__(self, dest, freq=None, duty_u16=None, duty_ns=None, invert=False):
            pid = dest.id if isinstance(dest, Pin) else dest
            if not _isint(pid) or pid < 0 or pid > 15:
                raise ValueError('invalid pin')
            self.pin = pid
            self.ch = pid & 3
            if freq is not None:
                self.freq(freq)
            if duty_u16 is not None:
                self.duty_u16(duty_u16)
            _pinmux(pid, 1 + self.ch)
            _poke32(MMIO_PWM_EN, _peek32(MMIO_PWM_EN) | (1 << self.ch))

        def freq(self, f=_MISSING):
            if f is _MISSING:
                return _peek32(MMIO_SYS_FREQ) // ((_peek32(MMIO_PWM_TOP) + 1) * (_peek32(MMIO_PWM_PRESC) + 1))
            return _pwm_set_freq(f, pwm_duty)

        def duty_u16(self, d=_MISSING):
            if d is _MISSING:
                return pwm_duty[self.ch]
            if d < 0 or d > 65535:
                raise ValueError('duty_u16 must be 0-65535')
            pwm_duty[self.ch] = d
            return _pwm_set_duty(self.ch, d)

        def duty_ns(self, ns=_MISSING):
            per = 1000000000 // self.freq()
            if ns is _MISSING:
                return pwm_duty[self.ch] * per // 65535
            return self.duty_u16(min(65535, ns * 65535 // per))

        def deinit(self):
            _poke32(MMIO_PWM_EN, _peek32(MMIO_PWM_EN) & ~(1 << self.ch))
            _pinmux(self.pin, 0)
            return None

    class SPI:
        MSB = 0
        LSB = 1

        def __init__(self, id, baudrate=1000000, polarity=0, phase=0, bits=8, firstbit=0,
                     sck=None, mosi=None, miso=None):
            if id != 0:
                raise ValueError('SPI does not exist')
            self.init(baudrate, polarity, phase, bits, firstbit, sck, mosi, miso)

        def init(self, baudrate=1000000, polarity=0, phase=0, bits=8, firstbit=0,
                 sck=None, mosi=None, miso=None):
            if bits != 8 or firstbit != 0:
                raise ValueError('only 8-bit MSB-first frames')
            hz = _peek32(MMIO_SYS_FREQ)
            div = hz // (2 * baudrate) - 1
            if div < 0:
                div = 0
            self.baudrate = hz // (2 * (div + 1))
            _pinmux(10 if sck is None else sck.id, 5)
            _pinmux(11 if mosi is None else mosi.id, 6)
            _pinmux(12 if miso is None else miso.id, 7)
            _poke32(MMIO_SPI_CTRL, (div << 8) | ((phase & 1) << 2) | ((polarity & 1) << 1) | 1)
            return None

        def deinit(self):
            _poke32(MMIO_SPI_CTRL, 0)
            return None

        def write(self, buf):
            b = _as_bytes(buf)
            _spi_xfer(b, 0, None, _slen(b))
            return None

        def read(self, nbytes, write=0):
            out = bytearray(nbytes)
            _spi_xfer(None, write & 255, out, nbytes)
            return bytes(out)

        def readinto(self, buf, write=0):
            _spi_xfer(None, write & 255, buf, len(buf))
            return None

        def write_readinto(self, wbuf, rbuf):
            b = _as_bytes(wbuf)
            if _slen(b) != len(rbuf):
                raise ValueError('buffers must be the same length')
            _spi_xfer(b, 0, rbuf, len(rbuf))
            return None

    class I2C:
        def __init__(self, id, *, scl=None, sda=None, freq=400000, timeout=50000):
            if id != 0:
                raise ValueError('I2C does not exist')
            self.init(scl=scl, sda=sda, freq=freq, timeout=timeout)

        def init(self, *, scl=None, sda=None, freq=400000, timeout=50000):
            hz = _peek32(MMIO_SYS_FREQ)
            # mpy_periph_model.i2c_config: DIV 16 bits, the timeout 32.
            div = hz // (4 * freq) - 1
            if div < 0:
                div = 0
            if div > 0xFFFF:
                div = 0xFFFF
            self.freq = hz // (4 * (div + 1))
            clocks = timeout * (hz // 1000000)
            if clocks > 0xFFFFFFFF:
                clocks = 0xFFFFFFFF
            _pinmux(14 if scl is None else scl.id, 8)
            _pinmux(15 if sda is None else sda.id, 9)
            _poke32(MMIO_I2C_DIV, div)
            _poke32(MMIO_I2C_TIMEOUT, _w32(clocks))
            _poke32(MMIO_I2C_CTRL, 1)
            return None

        def deinit(self):
            _poke32(MMIO_I2C_CTRL, 0)
            return None

        def scan(self):
            found = []
            a = 8
            while a < 120:
                _i2c_cmd(I2C_START)
                st = _i2c_cmd(I2C_WRITE | ((a << 1) << 8))
                _i2c_cmd(I2C_STOP)
                if not st & 2:
                    found.append(a)
                a += 1
            return found

        def start(self):
            _i2c_cmd(I2C_START)
            return None

        def stop(self):
            _i2c_cmd(I2C_STOP)
            return None

        def readinto(self, buf, nack=True):
            n = len(buf)
            i = 0
            while i < n:
                last = 1 if nack and i == n - 1 else 0
                buf[i] = (_i2c_cmd(I2C_READ | (last << 16)) >> 8) & 255
                i += 1
            return None

        def write(self, buf):
            b = _as_bytes(buf)
            n = _slen(b)
            acks = 0
            while acks < n:
                if _i2c_cmd(I2C_WRITE | (_byte(b, acks) << 8)) & 2:
                    break
                acks += 1
            return acks

        def writeto(self, addr, buf, stop=True):
            b = _as_bytes(buf)
            return _i2c_write(addr << 1, b, _slen(b), stop)

        def readfrom(self, addr, nbytes, stop=True):
            out = bytearray(nbytes)
            _i2c_read(addr, out, stop)
            return bytes(out)

        def readfrom_into(self, addr, buf, stop=True):
            _i2c_read(addr, buf, stop)
            return None

        def readfrom_mem(self, addr, memaddr, nbytes, *, addrsize=8):
            out = bytearray(nbytes)
            self.readfrom_mem_into(addr, memaddr, out, addrsize=addrsize)
            return bytes(out)

        def readfrom_mem_into(self, addr, memaddr, buf, *, addrsize=8):
            m = _i2c_memaddr(memaddr, addrsize)
            _i2c_write(addr << 1, m, len(m), False)
            _i2c_read(addr, buf, True)
            return None

        def writeto_mem(self, addr, memaddr, buf, *, addrsize=8):
            b = _as_bytes(buf)
            m = _i2c_memaddr(memaddr, addrsize)
            _i2c_write(addr << 1, m + b, len(m) + _slen(b), True)
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
        'PWM': PWM,
        'SPI': SPI,
        'I2C': I2C,
        'disable_irq': disable_irq,
        'enable_irq': enable_irq,
        'idle': idle,
        'freq': freq,
    }
    return _mk_builtin_module('machine', g)


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
    return _mk_builtin_module('time', {
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
