# Events on the hart: _irq_dispatch (the core calls it at a soft point when
# an enabled event is pending), the micropython.schedule queue, the heap
# lock, and kbd_intr. Spec: upycore/docs/mpy_io_core.md (Events on the
# hart). Linked only into images with the board I/O firmware.
#
# MicroPython v1.29.0 is the model: py/scheduler.c (at most one scheduled
# callback per pending check, run protected; a depth of 8 as on rp2,
# ports/rp2/mpconfigport.h), shared/runtime/mpirq.c (a soft IRQ handler is
# scheduled; a hard one runs at once with the scheduler and the heap
# locked, and an uncaught exception prints "Uncaught exception in IRQ
# callback handler" and disables the handler), py/runtime_utils.c
# (mp_call_function_1_protected prints the exception and goes on).
#
# Deviation (decision D2): a hard handler runs at the next soft point, like
# a soft one, not inside the interrupt; the heap is locked while it runs.
# Firmware functions are firmware frames: no soft point falls inside them,
# so a callback never runs halfway through one (or through the _io helpers
# machine uses), as one never runs halfway through a C function.

_EVT = const(0x00C)
_EVT_EN = const(0x010)
_EVT_SET = const(0x014)
_EVT_MASK = const(0x018)
_CMD = const(0x000)
_RSP = const(0x004)
_STATUS = const(0x008)
_CMD_SENT = const(0x028)
_PAGE = const(0x800)
_PG_PIN_FLAGS = const(2)
_PG_SEQ = const(7)
_PG_TIMER0 = const(8)
_PG_PIN_CNT = const(12)
_PG_UART0_EV = const(16)

_EV_SOFT = const(1)
_EV_KBD = const(2)
_EV_UART0 = const(4)
_EV_TIMER = const(8)
_EV_PIN = const(16)
_SCHED_DEPTH = const(8)


def _irq_state():
    st = _io_state()
    if 'q' not in st:
        st['q'] = []           # scheduled (function, argument), oldest first
        st['pin'] = {}         # pin id: [handler, Pin, trigger, hard, count seen]
        st['tmr'] = {}         # timer id: [callback, Timer, hard, count seen]
        st['uart'] = None      # [handler, UART, trigger, hard, events seen]
    return st


# ---- the _io helpers machine uses (no soft point inside any of them) ----

def mod__io__cmd(w):
    _st(_IO_BASE, 0, w)
    return None


def mod__io__cmd2(a, b):
    _st(_IO_BASE, 0, a)
    _st(_IO_BASE, 0, b)
    return None


def _rsp_wait():
    while mod__io__rd(_STATUS) >= 0:
        pass
    return mod__io__rd(_RSP)


def mod__io__req(w):
    # One command word, one answer word.
    _st(_IO_BASE, 0, w)
    return _rsp_wait()


def mod__io__req2(a, b):
    _st(_IO_BASE, 0, a)
    _st(_IO_BASE, 0, b)
    return _rsp_wait()


def mod__io__fence():
    # Wait until the I/O core has finished every command sent so far.
    n = mod__io__rd(_CMD_SENT)
    while mod__io__rd(_PAGE + 4 * _PG_SEQ) != n:
        pass
    return None


def mod__io__page(i):
    # A state-page word, after every command sent so far has run.
    mod__io__fence()
    return mod__io__rd(_PAGE + 4 * i)


def mod__io__uart_rx(n):
    # Up to n received bytes (n < 256), as bytes. UART_RX answers the count
    # k, then ceil(k/4) words of four bytes, low byte first, with the unused
    # bytes of the last word 0. Each word goes straight into the new bytes
    # object's data (word-aligned, _strnew allocates ceil(k/4) words of it),
    # so a word costs one RSP load and one store. STATUS is read once per
    # batch, not once per word: its RSP level never counts more words than
    # RSP holds (Clock domains), and only this command's answer is in RSP.
    _st(_IO_BASE, 0, 0x28000000 | n)
    k = _rsp_wait()
    if k == 0:
        return b''
    r = _strnew(k, TAG_BYTES)
    d = _data(r)
    nw = (k + 3) >> 2
    i = 0
    while i < nw:
        e = i + ((_peek32(_IO_BASE + _STATUS) >> 8) & 31)
        if e > nw:
            e = nw
        while i < e:
            _st(d, i, _peek32(_IO_BASE + _RSP))
            i += 1
    return _strfin(r)


def mod__io__uart_rx_into(buf, off, n):
    # Up to n received bytes (n < 256) into buf from byte off, for
    # machine.UART.readinto: buf is a bytearray or a writable memoryview of
    # one, and the bytes go in by the copy engine (_bcopy). Returns the
    # count (never past the end of buf), or -1 for any other buffer, before
    # sending anything.
    if _isbarr(buf):
        dst = buf
        end = _ld(buf, 0)
    elif _ismv(buf) and _ld(buf, 5):
        # The view's base is the bytearray's data block; _bcopy takes an
        # INT as a plain address.
        dst = _pay(_ld(buf, 2))
        off += _ld(buf, 3)
        end = _ld(buf, 3) + _ld(buf, 4)
    else:
        return -1
    if n > end - off:
        n = end - off
    if n <= 0:
        return 0
    r = mod__io__uart_rx(n)
    k = _slen(r)
    if k:
        _bcopy(dst, off, r, 0, k)
    return k


def mod__io__xfer(words, nrsp):
    # Command words, then nrsp answer words, as one exchange.
    for w in words:
        _st(_IO_BASE, 0, w)
    out = []
    while len(out) < nrsp:
        out.append(_rsp_wait())
    return out


def mod__io__reset(kind):
    # machine.reset (0) / soft_reset (1): the I/O core puts the peripherals
    # back (SYS_OP_RESET; a hard reset also stops the watchdog), the console
    # drains (CON empty, then the UART's TX idle), then the keyed store
    # resets the hart domain.
    mod__io__req(0x01040000 | (1 - kind))
    while (mod__io__rd(_STATUS) >> 24) & 127:
        pass
    mod__io__fence()
    while mod__io__rd(_PAGE + 4 * 6) < 0:
        pass
    _st(_IO_BASE + 0x030, 0, 0x0B007ED0 | kind)
    while True:
        pass


def mod__io__wfe(cycles):
    return _wfe(cycles)


def mod__io__evt_enable(bits, on):
    en = mod__io__rd(_EVT_EN)
    _st(_IO_BASE + _EVT_EN, 0, (en | bits) if on else (en & ~bits))
    return None


def mod__io__set_handler(kind, key, entry):
    # Pin.irq, Timer and UART.irq register here (entry None: remove).
    st = _irq_state()
    if kind == 'uart':
        st['uart'] = entry
        return None
    d = st[kind]
    if entry is None:
        if key in d:
            del d[key]
    else:
        d[key] = entry
    return None


def mod__io__disable_irq():
    m = mod__io__rd(_EVT_MASK)
    _st(_IO_BASE + _EVT_MASK, 0, m | 2)
    return m & 2 == 0


def mod__io__enable_irq(state):
    m = mod__io__rd(_EVT_MASK)
    _st(_IO_BASE + _EVT_MASK, 0, (m & ~2) if state else (m | 2))
    return None


# ---- micropython: schedule, heap lock, kbd_intr ----

def _mp_sched(func, arg):
    q = _irq_state()['q']
    if len(q) >= _SCHED_DEPTH:
        raise RuntimeError('schedule queue full')
    q.append((func, arg))
    _st(_IO_BASE + _EVT_SET, 0, _EV_SOFT)
    return None


def _mp_lock():
    _hlock()
    return None


def _mp_unlock():
    return _hunlock()


def _mp_kbd(c):
    # The console's interrupt character (-1: none). The I/O core turns it
    # into the KBD event instead of a console byte.
    if c < 0:
        _st(_IO_BASE, 0, 0x06000000)
    else:
        _st(_IO_BASE, 0, 0x06000100 | (c & 255))
    return None


# ---- dispatch ----

def _irq_print(out, e):
    # mp_obj_print_exception (py/obj.c): the "Traceback" header and frames
    # only when there are frames (a hard handler, with the heap locked,
    # records none), then the exception.
    tb = NULL
    if _tag(e) == TAG_OBJECT and (_ld(e, 0) == OB_EXCEPTION or _ld(e, 0) == OB_INSTANCE):
        tb = _ld(e, 3)
    if tb is not NULL and len(tb) > 0:
        out('Traceback (most recent call last):\n')
        i = len(tb) - 2
        items = _ld(tb, 2)
        while i >= 0:
            _print_frame(out, _ld(items, i), _ld(items, i + 1))
            i -= 2
    _print_exc_line(out, e)
    return None


def _print_tb_out(e):
    # mp_call_function_1_protected prints to mp_plat_print: stdout.
    _irq_print(_wr, e)

def _irq_hard(entry, idx, obj):
    # A hard handler: now, with the heap locked; on an exception, the
    # message, the exception, and the handler is disabled.
    _hlock()
    try:
        entry[0](obj)
    except BaseException as e:
        _hunlock()
        _we('Uncaught exception in IRQ callback handler\n')
        _irq_print(_we, e)
        entry[0] = None
        return False
    _hunlock()
    return True


def _irq_fire(entry, obj):
    if entry[0] is None:
        return
    if entry[3 if len(entry) > 4 else 2]:
        _irq_hard(entry, 0, obj)
    else:
        q = _irq_state()['q']
        if len(q) < _SCHED_DEPTH:
            q.append((entry[0], obj))


def _irq_dispatch():
    m = mod__io__rd(_EVT_MASK)
    _st(_IO_BASE + _EVT_MASK, 0, m | 1)
    ev = mod__io__rd(_EVT) & mod__io__rd(_EVT_EN)
    _st(_IO_BASE + _EVT, 0, ev)
    if ev & _EV_KBD:
        _st(_IO_BASE + _EVT_MASK, 0, m & ~1)
        raise KeyboardInterrupt
    st = _irq_state()
    if ev & _EV_PIN:
        for pid in st['pin']:
            e = st['pin'][pid]
            w = mod__io__rd(_PAGE + 4 * (_PG_PIN_CNT + pid // 4))
            c = (w >> (8 * (pid % 4))) & 255
            if c != e[4]:
                e[4] = c
                _irq_fire(e, e[1])
    if ev & _EV_TIMER:
        for tid in st['tmr']:
            e = st['tmr'][tid]
            c = mod__io__rd(_PAGE + 4 * (_PG_TIMER0 + tid))
            n = (c - e[3]) & 0xFFFFFFFF
            if n > 4:
                n = 4
            e[3] = c
            while n > 0 and e[0] is not None:
                if e[2]:
                    _irq_hard(e, 0, e[1])
                else:
                    q = st['q']
                    if len(q) < _SCHED_DEPTH:
                        q.append((e[0], e[1]))
                n -= 1
    if ev & _EV_UART0:
        e = st['uart']
        if e is not None:
            w = mod__io__rd(_PAGE + 4 * _PG_UART0_EV)
            if (w & 0xFFFF) != e[4]:
                e[4] = w & 0xFFFF
                _irq_fire(e, e[1])
    # At most one scheduled callback per dispatch (py/scheduler.c).
    q = st['q']
    if len(q):
        fn, arg = q.pop(0)
        try:
            fn(arg)
        except BaseException as e:
            _print_tb_out(e)
    if len(q):
        _st(_IO_BASE + _EVT_SET, 0, _EV_SOFT)
    _st(_IO_BASE + _EVT_MASK, 0, mod__io__rd(_EVT_MASK) & ~1)
    return None
