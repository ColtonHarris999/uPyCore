# The REPL on the console: friendly, raw, and paste mode, after v1.29.0
# shared/runtime/pyexec.c and py/repl.c (upycore/docs/mpy_peripherals.md,
# REPL). Lines compile with the on-device compiler.

CTRL_A = const(1)
CTRL_B = const(2)
CTRL_C = const(3)
CTRL_D = const(4)
CTRL_E = const(5)
KEEP_RAW = const(1)


def _repl_banner():
    _wr('MicroPython v1.29.0 on 2026-10-14; upycore with mpy_core\r\n')
    _wr('Type "help()" for more information.\r\n')
    return None


def _repl_soft_reset(raw):
    # SYS_KEEP survives the reset, so a raw REPL comes back raw.
    _poke32(MMIO_SYS_KEEP, KEEP_RAW if raw else 0)
    _wr('MPY: soft reboot\r\n')
    _con_flush()
    _poke32(MMIO_SYS_RESET, SYS_RESET_KEY | 1)
    while True:
        pass


def _repl_kbd(on):
    # Ctrl-C interrupts running code; while a line is read it is a character.
    if (_peek32(MMIO_SYS_CONSOLE) & 3) == 1:
        _mp_kbd(3 if on else -1)
    return None


def _repl_run(src, mode, g, eof):
    # parse_compile_execute: eof marks the end of output and of the error
    # text with 0x04, as the raw REPL does. A SystemExit soft-resets.
    _repl_kbd(True)
    exc = NULL
    try:
        exec(compile(src, '<stdin>', mode), g)
    except BaseException as e:
        exc = e
    _repl_kbd(False)
    if eof:
        _wr('\x04')
    ok = True
    if exc is not NULL:
        if isinstance(exc, SystemExit):
            ok = False
        else:
            _print_tb(exc)
    if eof:
        _wr('\x04')
    return ok


def _repl_word(src, w):
    # src starts with keyword w followed by a non-identifier character.
    n = _slen(w)
    if _slen(src) < n or not _streq(_substr(src, 0, n, TAG_STR), w):
        return False
    if _slen(src) == n:
        return True
    c = _byte(src, n)
    return not (c == 95 or (48 <= c <= 57) or (65 <= c <= 90) or (97 <= c <= 122) or c >= 128)


def _repl_more(src):
    # mp_repl_continue_with_input: does the statement need another line?
    n = _slen(src)
    if n == 0:
        return False
    compound = _byte(src, 0) == 64
    for w in ('if', 'while', 'for', 'try', 'with', 'def', 'class', 'async'):
        if _repl_word(src, w):
            compound = True
    depth = 0
    quote = 0
    triple = False
    i = 0
    while i < n:
        c = _byte(src, i)
        if quote:
            if c == 92:
                i += 1
            elif c == quote:
                if not triple:
                    quote = 0
                elif i + 2 < n and _byte(src, i + 1) == c and _byte(src, i + 2) == c:
                    quote = 0
                    i += 2
        elif c == 39 or c == 34:
            quote = c
            triple = i + 2 < n and _byte(src, i + 1) == c and _byte(src, i + 2) == c
            if triple:
                i += 2
        elif c == 35:
            while i < n and _byte(src, i) != 10:
                i += 1
        elif c == 40 or c == 91 or c == 123:
            depth += 1
        elif c == 41 or c == 93 or c == 125:
            depth -= 1
        i += 1
    if quote and triple:
        return True
    if depth > 0 and not quote:
        return True
    if _byte(src, n - 1) == 92:
        return True
    return compound and _byte(src, n - 1) != 10


def _repl_line(buf, prompt):
    # readline: edit into buf with echo. Returns 0 on Enter, or the control
    # character (Ctrl-A, B, C, D, E) that ended it; -1 at the end of input.
    _wr(prompt)
    while True:
        c = _con_getc()
        if c < 0:
            return -1
        if c == 13 or c == 10:
            _wr('\r\n')
            return 0
        if c == CTRL_A or c == CTRL_B or c == CTRL_C or c == CTRL_E:
            return c
        if c == CTRL_D:
            if len(buf) == 0:
                return c
            continue
        if c == 8 or c == 127:
            if len(buf) > 0:
                buf.pop()
                _wr('\b \b')
            continue
        if c < 32 and c != 9:
            continue
        buf.append(c)
        _wr(c)


def _repl_paste(g):
    _wr('\r\npaste mode; Ctrl-C to cancel, Ctrl-D to finish\r\n=== ')
    buf = bytearray()
    while True:
        c = _con_getc()
        if c < 0 or c == CTRL_C:
            _wr('\r\n')
            return None
        if c == CTRL_D:
            _wr('\r\n')
            _repl_run(str(bytes(buf), 'utf-8'), 'exec', g, False)
            return None
        if c == 13:
            c = 10
        buf.append(c)
        if c == 10:
            _wr('\r\n=== ')
        else:
            _wr(c)


def _repl_friendly(g):
    # Returns True to go to the raw REPL; -1 input ends it (False).
    _repl_banner()
    while True:
        buf = bytearray()
        r = _repl_line(buf, '>>> ')
        if r == CTRL_A:
            _wr('\r\n')
            return True
        if r == CTRL_B:
            _wr('\r\n')
            _repl_banner()
            continue
        if r == CTRL_C:
            _wr('\r\n')
            continue
        if r == CTRL_D:
            _wr('\r\n')
            _repl_soft_reset(False)
        if r == CTRL_E:
            _repl_paste(g)
            continue
        if r < 0:
            return False
        while _repl_more(str(bytes(buf), 'utf-8')):
            buf.append(10)
            r = _repl_line(buf, '... ')
            if r == CTRL_C:
                _wr('\r\n')
                buf = NULL
                break
            if r == CTRL_D or r < 0:
                break
        if buf is NULL or len(buf) == 0:
            continue
        if not _repl_run(str(bytes(buf), 'utf-8'), 'single', g, False):
            _repl_soft_reset(False)


def _repl_raw(g):
    # Returns True to go to the friendly REPL; -1 input ends it (False).
    _wr('raw REPL; CTRL-B to exit\r\n')
    while True:
        _wr('>')
        buf = bytearray()
        while True:
            c = _con_getc()
            if c < 0:
                return False
            if c == CTRL_A:
                continue
            if c == CTRL_B:
                _wr('\r\n')
                return True
            if c == CTRL_C:
                buf = bytearray()
                continue
            if c == CTRL_E and len(buf) == 0:
                # Raw paste (Ctrl-E A Ctrl-A): not supported.
                _con_getc()
                _con_getc()
                _wr('R\x00')
                continue
            if c == CTRL_D:
                break
            buf.append(c)
        if len(buf) == 0:
            _wr('\r\n')
            _repl_soft_reset(True)
        _wr('OK')
        if not _repl_run(str(bytes(buf), 'utf-8'), 'exec', g, True):
            _repl_soft_reset(True)


def _repl(g):
    # Until the console has no more input (the sim console has none).
    raw = bool(_peek32(MMIO_SYS_KEEP) & KEEP_RAW)
    _poke32(MMIO_SYS_KEEP, 0)
    _repl_kbd(False)
    while True:
        if raw:
            if not _repl_raw(g):
                return None
            raw = False
        else:
            if not _repl_friendly(g):
                return None
            raw = True
