# The console's input side and sys's streams, for images that use board I/O
# or the console (mpy_build.io_imports). Spec: upycore/docs/mpy_io_core.md
# (Console).
#
# Output is unchanged: print and the streams write through _wr and _we,
# stores to the simulator page, which mpy_soc sends to the console the
# strap picks (the simulator page, the I/O core's UART or its USB CDC).
# Input comes from the bridge's CON_RX: the I/O core fills it from the UART
# or from CDC OUT. With the sim strap nothing does, and input is at its end.
#
# sys.stdin, sys.stdout and sys.stderr are native modules (the firmware
# body cannot define classes); each has the methods MicroPython's streams
# have for this use. input() follows py/modbuiltins.c and the line editing
# of shared/readline/readline.c in MicroPython v1.29.0: printable bytes
# echo, Enter (CR, LF, or one CR LF pair) echoes CR LF and ends the line,
# backspace (8 or 127) erases one character with "\b\x1b[K", Ctrl-C raises
# KeyboardInterrupt, Ctrl-D on an empty line raises EOFError, and escape
# sequences are read and dropped.

_CON_RX = const(0x020)
_CON_MODE = const(0x024)
_IOC_RUN = const(0x01C)
# The board I/O firmware's state: a dict in sysroot word 28, a GC root
# (mpy_abi.SR leaves 28 free for it; the number is here, not in _abi.py, so
# the base firmware does not change).
_SR_IO = const(28)


def _io_state():
    st = _sysget(_SR_IO)
    if st is NULL:
        st = {'nl': 0}
        _sysset(_SR_IO, st)
    return st


def _con_live():
    # A console that can ever have input: a UART or USB strap and a running
    # I/O core.
    return (mod__io__rd(_CON_MODE) & 3) != 0 and (mod__io__rd(_IOC_RUN) & 1) != 0


def _con_byte(block):
    # The next input byte, or -1 at the end of input (or none waiting and
    # not block).
    while True:
        w = mod__io__rd(_CON_RX)
        if w < 0:
            return w & 255
        if not block or not _con_live():
            return -1


def _readline_edit():
    # (line, ending): ending 0 Enter, 3 Ctrl-C, 4 Ctrl-D, -1 end of input.
    # The line is a list of byte values (a bytearray has no pop).
    buf = []
    esc = 0
    while True:
        c = _con_byte(True)
        if c < 0:
            return buf, -1
        if esc == 1:
            esc = 2 if c == 91 or c == 79 else 0
            continue
        if esc == 2:
            if c < 64:
                continue
            esc = 0
            continue
        if (c == 13 or c == 10):
            st = _io_state()
            last = st['nl']
            if last == 0 or last == c:
                st['nl'] = c
                _wr('\r\n')
                return buf, 0
            st['nl'] = 0
            continue
        _io_state()['nl'] = 0
        if 1 <= c <= 5 and len(buf) == 0:
            return buf, c
        if c == 3:
            return buf, 3
        if c == 27:
            esc = 1
        elif c == 8 or c == 127:
            if len(buf):
                buf.pop()
                _wr('\b\x1b[K')
        elif c >= 32:
            buf.append(c)
            _wr(c)


def input(*args, **kw):
    if kw:
        raise TypeError("function doesn't take keyword arguments")
    if len(args) > 1:
        raise TypeError('function takes at most 1 positional arguments')
    if args:
        _wr(_str(args[0]))
    line, ret = _readline_edit()
    if ret == 3:
        raise KeyboardInterrupt
    if len(line) == 0 and (ret == 4 or ret == -1):
        raise EOFError
    return str(bytes(line), 'utf-8')


def mod__stdin__read(n=-1):
    out = bytearray()
    while n < 0 or len(out) < n:
        c = _con_byte(True)
        if c < 0:
            break
        out.append(c)
    return str(out, 'utf-8')


def mod__stdin__readline(n=-1):
    out = bytearray()
    while n < 0 or len(out) < n:
        c = _con_byte(True)
        if c < 0:
            break
        out.append(c)
        if c == 10:
            break
    return str(out, 'utf-8')


def mod__stdout__write(s):
    _wr(s)
    return _slen(s) if not _isint(s) else 1


def mod__stderr__write(s):
    _we(s)
    return _slen(s) if not _isint(s) else 1


def mod__stdout__flush():
    return None


def mod__stderr__flush():
    return None


_io_build_sys = _build_sys


def _build_sys(filename):
    # Called by _boot before __main__: the board I/O firmware's start. The
    # schedule and the console's interrupt character are live from here
    # (EVT_EN bits 0 and 1); the I/O core arms Ctrl-C on a uart or usb
    # console.
    _st(_IO_BASE + 0x010, 0, mod__io__rd(0x010) | 3)
    m = _io_build_sys(filename)
    g = _ld(m, 2)
    g['stdin'] = _dget(_NATIVE_MODULES, '_stdin')
    g['stdout'] = _dget(_NATIVE_MODULES, '_stdout')
    g['stderr'] = _dget(_NATIVE_MODULES, '_stderr')
    return m
