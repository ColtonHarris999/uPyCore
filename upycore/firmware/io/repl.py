# The REPL: MicroPython's friendly and raw REPL on the UART (or USB)
# console, for REPL images only (mpy_build.build_program(repl=True)); it
# replaces _boot. Spec: upycore/docs/mpy_io_core.md (REPL).
#
# MicroPython v1.29.0 is the model: shared/runtime/pyexec.c
# (pyexec_friendly_repl, pyexec_raw_repl, parse_compile_execute, the
# raw-paste reader), shared/readline/readline.c (line editing with
# auto-indent, cursor at the end of the line), py/repl.c
# (mp_repl_continue_with_input) and ports/rp2/main.c (main.py, then the
# REPL; "MPY: soft reboot" and the REPL mode kept across a soft reset).
#
# With the sim strap there is no console input: the image runs its
# program and halts, as every image does.
#
# Not here: history and the arrow keys (escape sequences are read and
# dropped), tab completion, emacs keys, and MICROPY_REPL_INFO.

_KEEP = const(0x034)
_KEEP_RAW = const(1)
_BANNER = 'MicroPython 062cf49b48 on 2026-10-14; upycore\r\n'
_FORCED_EXIT = const(0x100)
# MICROPY_REPL_STDIN_BUFFER_MAX: the raw-paste flow-control window is half.
_PASTE_WINDOW = const(128)


def __repl_print__(o):
    # py/modbuiltins.c mp_builtin___repl_print__: the repr of a value that
    # is not None, on its own line. (Without MICROPY_CAN_OVERRIDE_BUILTINS
    # there is no "_".)
    if o is not None:
        _wr(repr(o))
        _wr('\n')
    return None


def _rx():
    # mp_hal_stdin_rx_chr: the next console byte, waiting for it.
    while True:
        w = mod__io__rd(_CON_RX)
        if w < 0:
            return w & 255


def _kbd_off():
    # mp_hal_set_interrupt_char(-1), then the pending Ctrl-C is dropped
    # (MP_HANDLE_PENDING_CALLBACKS_AND_CLEAR_EXCEPTIONS).
    _mp_kbd(-1)
    mod__io__fence()
    _st(_IO_BASE + _EVT, 0, _EV_KBD)


def _execute(src, mode, eof, g):
    # parse_compile_execute: compile, run with Ctrl-C armed, and print an
    # exception to stdout. eof: the raw REPL's two \x04 markers. Returns
    # 0, or _FORCED_EXIT for SystemExit (a soft reset).
    ret = 0
    try:
        fun = compile(src, '<stdin>', mode)
        src = None
        _st(fun, 6, g)
        _mp_kbd(3)
        _callns(fun, g)
        _kbd_off()
        if eof:
            _wr('\x04')
    except SystemExit:
        _kbd_off()
        if eof:
            _wr('\x04')
        ret = _FORCED_EXIT
    except BaseException as e:
        _kbd_off()
        if eof:
            _wr('\x04')
        _print_tb_out_full(e)
    if eof:
        _wr('\x04')
    return ret


def _print_tb_out_full(e):
    # mp_obj_print_exception to mp_plat_print (stdout): with a traceback
    # header even when the compile error has no frames, as for a user
    # program's exception.
    tb = NULL
    if _tag(e) == TAG_OBJECT and (_ld(e, 0) == OB_EXCEPTION or _ld(e, 0) == OB_INSTANCE):
        tb = _ld(e, 3)
    if tb is not NULL and len(tb) > 0:
        _wr('Traceback (most recent call last):\n')
        i = len(tb) - 2
        items = _ld(tb, 2)
        while i >= 0:
            _print_frame(_wr, _ld(items, i), _ld(items, i + 1))
            i -= 2
    _print_exc_line(_wr, e)
    return None


# ---- readline (shared/readline/readline.c), the cursor at the end ----

def _back(n):
    # mp_hal_move_cursor_back
    if n <= 0:
        return
    if n <= 4:
        _wr('\b\b\b\b'[:n])
    else:
        _wr('\x1b[')
        _wr(_istr(n))
        _wr('D')


def _auto_indent(line, st):
    # readline_auto_indent: line is the text so far (earlier lines, each
    # ending in \n). Returns the indent added.
    n = len(line)
    if n <= 1 or line[n - 1] != 10:
        return 0
    i = n - 1
    while i > 0 and line[i - 1] != 10:
        i -= 1
    j = i
    while j < n and line[j] == 32:
        j += 1
    if i > 0 and j + 1 == n:
        k = i - 1
        while k > 0:
            if line[k - 1] == 10:
                return 0
            if line[k - 1] != 32:
                break
            k -= 1
    m = (j - i) // 4
    if line[n - 2] == 58:
        m += 1
    added = 0
    while m > 0:
        line.extend(b'    ')
        _wr('    ')
        added += 4
        st['just'] = True
        m -= 1
    return added


def _readline(line, prompt, st):
    # readline(): edits line (a bytearray; its earlier text stays). Returns
    # 0 for Enter, or the control character that ended it (Ctrl-A..E on an
    # empty line, Ctrl-C).
    orig = len(line)
    _wr(prompt)
    if orig == 0:
        st['auto'] = True
    st['just'] = False
    if st['auto']:
        _auto_indent(line, st)
    esc = 0
    while True:
        c = _rx()
        just = st['just']
        st['just'] = False
        if esc == 1:
            esc = 2 if c == 91 else (3 if c == 79 else 0)
            continue
        if esc == 2:
            if 48 <= c <= 57:
                continue
            esc = 0
            continue
        if esc == 3:
            esc = 0
            continue
        if 1 <= c <= 5 and len(line) == orig:
            return c
        if c == 3:
            return c
        if (c == 13 or c == 10) and (st['nl'] == 0 or st['nl'] == c):
            st['nl'] = c
            _wr('\r\n')
            return 0
        st['nl'] = 0
        if c == 13 or c == 10:
            continue
        if c == 27:
            esc = 1
        elif c == 8 or c == 127:
            if len(line) > orig:
                ns = 0
                k = orig
                while k < len(line):
                    if line[k] != 32:
                        ns = 0
                        break
                    ns += 1
                    k += 1
                ns = 1 if ns < 4 else 4
                del line[len(line) - ns:]
                _back(ns)
                _wr('\x1b[K')
        elif just and (c == 9 or c == 32):
            st['auto'] = False
            if c == 32:
                del line[len(line) - 3:]
                _back(3)
        elif c == 9:
            if len(line) > 0 and (line[len(line) - 1] == 32 or line[len(line) - 1] == 10):
                line.extend(b'    ')
                _wr('    ')
        elif 32 <= c <= 126:
            line.append(c)
            _wr(c)


def _startswith_word(s, w):
    n = len(w)
    if len(s) < n or s[:n] != w:
        return False
    if len(s) == n:
        return True
    c = s[n]
    return not (c == 95 or 48 <= c <= 57 or 65 <= c <= 90 or 97 <= c <= 122 or c >= 128)


def _continue(s):
    # mp_repl_continue_with_input (py/repl.c), on bytes.
    if len(s) == 0:
        return False
    comp = (s[0] == 64 or _startswith_word(s, b'if') or _startswith_word(s, b'while')
            or _startswith_word(s, b'for') or _startswith_word(s, b'try')
            or _startswith_word(s, b'with') or _startswith_word(s, b'def')
            or _startswith_word(s, b'class') or _startswith_word(s, b'async'))
    paren = 0
    brack = 0
    brace = 0
    q = 0
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == 39:
            if (q == 0 or q == 3) and i + 2 < n and s[i + 1] == 39 and s[i + 2] == 39:
                i += 2
                q = 3 - q
            elif q == 0 or q == 1:
                q = 1 - q
        elif c == 34:
            if (q == 0 or q == 4) and i + 2 < n and s[i + 1] == 34 and s[i + 2] == 34:
                i += 2
                q = 4 - q
            elif q == 0 or q == 2:
                q = 2 - q
        elif c == 92 and i + 1 < n and (s[i + 1] == 39 or s[i + 1] == 34 or s[i + 1] == 92):
            if q != 0:
                i += 1
        elif q == 0:
            if c == 40:
                paren += 1
            elif c == 41:
                paren -= 1
            elif c == 91:
                brack += 1
            elif c == 93:
                brack -= 1
            elif c == 123:
                brace += 1
            elif c == 125:
                brace -= 1
        i += 1
    if q == 3 or q == 4:
        return True
    if (paren > 0 or brack > 0 or brace > 0) and q == 0:
        return True
    if s[n - 1] == 92:
        return True
    if comp and s[n - 1] != 10:
        return True
    return False


# ---- the two REPLs ----

def _friendly(g):
    # pyexec_friendly_repl. Returns 1 to change to the raw REPL, or
    # _FORCED_EXIT for a soft reset.
    st = {'nl': 0, 'auto': True, 'just': False}
    _wr(_BANNER)
    _wr('Type "help()" for more information.\r\n')
    while True:
        _hunlock_all()
        line = bytearray()
        r = _readline(line, '>>> ', st)
        mode = 'single'
        if r == 1:
            _wr('\r\n')
            return 1
        elif r == 2:
            _wr('\r\n')
            _wr(_BANNER)
            _wr('Type "help()" for more information.\r\n')
            continue
        elif r == 3:
            _wr('\r\n')
            continue
        elif r == 4:
            _wr('\r\n')
            return _FORCED_EXIT
        elif r == 5:
            _wr('\r\npaste mode; Ctrl-C to cancel, Ctrl-D to finish\r\n=== ')
            line = bytearray()
            cancel = False
            while True:
                c = _rx()
                if c == 3:
                    _wr('\r\n')
                    cancel = True
                    break
                if c == 4:
                    _wr('\r\n')
                    break
                line.append(c)
                if c == 13:
                    _wr('\r\n=== ')
                else:
                    _wr(c)
            if cancel:
                continue
            mode = 'exec'
        elif len(line) == 0:
            continue
        else:
            cancel = False
            while _continue(line):
                line.append(10)
                r = _readline(line, '... ', st)
                if r == 3:
                    _wr('\r\n')
                    cancel = True
                    break
                if r == 4:
                    break
            if cancel:
                continue
        ret = _execute(str(line, 'utf-8'), mode, False, g)
        line = None
        if ret & _FORCED_EXIT:
            return ret


def _raw(g):
    # pyexec_raw_repl. Returns 0 to change to the friendly REPL, or
    # _FORCED_EXIT for a soft reset.
    _wr('raw REPL; CTRL-B to exit\r\n')
    while True:
        line = bytearray()
        _wr('>')
        while True:
            c = _rx()
            if c == 1:
                if len(line) == 2 and line[0] == 5:
                    ret = _paste(line[1], g)
                    if ret & _FORCED_EXIT:
                        return ret
                    line = bytearray()
                    _wr('>')
                    continue
                _wr('raw REPL; CTRL-B to exit\r\n')
                line = bytearray()
                _wr('>')
                continue
            if c == 2:
                _wr('\r\n')
                return 0
            if c == 3:
                line = bytearray()
            elif c == 4:
                break
            else:
                line.append(c)
        _wr('OK')
        if len(line) == 0:
            _wr('\r\n')
            return _FORCED_EXIT
        ret = _execute(str(line, 'utf-8'), 'exec', True, g)
        line = None
        if ret & _FORCED_EXIT:
            return ret


def _paste(cmd, g):
    # do_reader_stdin: raw-paste mode ("\x05A\x01"). The host sends at
    # most a window of bytes, then waits for \x01 granting the next one;
    # Ctrl-D ends the source, Ctrl-C ends it with KeyboardInterrupt.
    if cmd != 65:
        _wr('R\x00')
        return 0
    _wr('R\x01')
    _wr(_PASTE_WINDOW & 255)
    _wr(_PASTE_WINDOW >> 8)
    _wr(1)
    buf = bytearray()
    remain = _PASTE_WINDOW
    kbd = False
    while True:
        c = _rx()
        if c == 3 or c == 4:
            _wr('\x04')
            kbd = c == 3
            break
        buf.append(c)
        remain -= 1
        if remain == 0:
            _wr(1)
            remain = _PASTE_WINDOW
    if kbd:
        # The reader raised KeyboardInterrupt before anything ran.
        _wr('\x04')
        _wr('KeyboardInterrupt: \n')
        _wr('\x04')
        return 0
    return _execute(str(buf, 'utf-8'), 'exec', True, g)


def _hunlock_all():
    # pyexec: "If the GC is locked at this point there is no way out except
    # a reset", so the heap lock depth goes back to 0.
    _hlock()
    while _hunlock() > 0:
        pass
    return None


def _boot():
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
    live = _con_live()
    keep = mod__io__rd(_KEEP)
    raw = (keep & _KEEP_RAW) != 0
    # ports/rp2/main.c runs main.py only in the friendly REPL mode (a soft
    # reset from the raw REPL, as mpremote does, does not run it).
    if not raw:
        _mp_kbd(3)
        try:
            _callns(md, g)
        except SystemExit as e:
            if not live:
                _halt(_sysexit(e))
            _soft_reboot(raw)
        except BaseException as e:
            if not live:
                _print_tb(e)
                _halt(1)
            _kbd_off()
            _print_tb_out_full(e)
        if not live:
            _halt(0)
    md = None
    _kbd_off()
    while True:
        if raw:
            r = _raw(g)
            if r & _FORCED_EXIT:
                break
            raw = False
        else:
            r = _friendly(g)
            if r & _FORCED_EXIT:
                break
            raw = True
    _soft_reboot(raw)


def _soft_reboot(raw):
    # soft_reset_exit: the message, then the hart domain resets with the
    # REPL mode kept in the bridge's KEEP word.
    _wr('MPY: soft reboot\n')
    k = mod__io__rd(_KEEP)
    _st(_IO_BASE + _KEEP, 0, (k | _KEEP_RAW) if raw else (k & ~_KEEP_RAW))
    mod__io__reset(1)
