# Program entry. _boot is the first firmware call: it builds the standard
# modules, runs __main__, and turns an uncaught exception into the unix
# port's exit status.
from ._abi import *


def _line_at(rc, off):
    info = _peek32(rc + 4 * RC_LINE_INFO)
    end = _peek32(rc + 4 * RC_LINE_INFO_END)
    line = 1
    while info < end:
        c = _peek8(info, 0)
        if (c & 128) == 0:
            b = c & 31
            l = c >> 5
            info += 1
        else:
            b = c & 15
            l = ((c << 4) & 1792) | _peek8(info, 1)
            info += 2
        if off >= b:
            off -= b
            line += l
        else:
            break
    return line


def _print_frame(out, rc, off):
    out('  File "')
    out(_mk(TAG_QSTR, _peek32(rc + 4 * RC_SOURCE_FILE)))
    out('", line ')
    out(_istr(_line_at(rc, off)))
    out(', in ')
    out(_mk(TAG_QSTR, _peek32(rc + 4 * RC_NAME)))
    out('\n')


def _print_exc_line(out, e):
    if _tag(e) == TAG_OBJECT and (_ld(e, 0) == OB_EXCEPTION or _ld(e, 0) == OB_INSTANCE):
        if _isuser(e):
            f = _user_method(e, '__repr__')
            if f is not NULL:
                out(_str(_call_member(f, e, ())))
                out('\n')
                return
        out(_tname(e))
        out(': ')
        out(_exc_args_str(e))
        out('\n')
        return
    out(_str(e))
    out('\n')


def _print_tb(e, file=_MISSING):
    return _print_tb_to(_we if file is NULL or file == _MISSING else _stream_writer(file), e)


def _print_tb_to(out, e):
    out('Traceback (most recent call last):\n')
    if _tag(e) == TAG_OBJECT and (_ld(e, 0) == OB_EXCEPTION or _ld(e, 0) == OB_INSTANCE):
        tb = _ld(e, 3)
        if tb is not NULL:
            n = len(tb)
            i = n - 2
            items = _ld(tb, 2)
            while i >= 0:
                _print_frame(out, _ld(items, i), _ld(items, i + 1))
                i -= 2
    _print_exc_line(out, e)
    return None


def _sysexit(e):
    args = _ld(e, 2)
    if len(args) == 0 or args[0] is None:
        return 0
    v = args[0]
    if not _isint(v):
        return 1
    return v & 255


def _warn(code):
    _we('Warning: exception chaining not supported\n')
    return None


# Every IRQ and micropython.schedule callback runs in this frame, whose
# return kind is RK_IRQ. An exception that leaves it goes to _irq_uncaught.
def _irq_call(fn, arg):
    fn(arg)
    return None


# An exception escaped a callback. The core stored it at SR_IRQ_EXC and
# filled the interrupted frame. A hard callback still holds the heap lock:
# the banner and the source disable allocate nothing, then done unlocks it
# (mp_irq_handler in shared/runtime/mpirq.c). A soft or schedule callback
# keeps its source armed and prints on stdout (mp_call_function_1_protected).
def _irq_uncaught(hard, src):
    if hard:
        _we('Uncaught exception in IRQ callback handler\n')
        _irq_handler(src, NULL, NULL)
        _poke32(MMIO_IRQ_ENABLE, _peek32(MMIO_IRQ_ENABLE) & ~(1 << src))
    _irq_done()
    exc = _sysget(SR_IRQ_EXC)
    _sysset(SR_IRQ_EXC, NULL)
    if exc is not NULL:
        _print_tb_to(_we if hard else _wr, exc)
    return None


def _boot():
    # Strap bit 0: the testbench drives timer_step. Otherwise a tick is 1 ms.
    if not (_peek32(MMIO_SYS_STRAP) & 1):
        _poke32(MMIO_TIMER_PRESC, _peek32(MMIO_SYS_FREQ) // 1000)
    mods = {}
    _sysset(SR_MODULES, mods)
    _sysset(SR_FW4, True)
    md = _peek32(HDR_MAIN_ADDR)
    filename = _mk(TAG_QSTR, _peek32(md + 4 * MD_SOURCE_FILE))
    sys = _build_sys(filename)
    _sysset(SR_FW1, sys)
    _sysset(SR_FW2, _build_gc())
    _sysset(SR_FW3, _build_mp())
    g = {}
    g['__name__'] = '__main__'
    g['__file__'] = filename
    g['sys'] = sys
    _sysset(SR_MAIN, _mk_module('__main__', g))
    _sysset(SR_FW0, g)
    try:
        _callns(md, g)
    except SystemExit as e:
        _halt(_sysexit(e))
    except BaseException as e:
        _print_tb(e)
        _halt(1)
    _halt(0)
