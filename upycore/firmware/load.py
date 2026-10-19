# Device loader and compile/exec/eval.
#
# compile() runs the frozen compiler as separate calls and collects after
# each one, so the parse tree is dead before the emitter's buffers peak.
# The .mpy bytes are then turned into a function whose word 7 keeps every
# heap block the bytecode points at. MAKE_FUNCTION copies that word, so a
# nested function keeps the buffer after compile() has returned.
from ._abi import *

_RC_FLAG_GENERATOR = const(2)
_SCOPE_VARKW = const(2)
_SCOPE_VARARGS = const(4)
# Bytecode format groups, from the v6 encoding. A nibble's two bits are
# 0 byte, 1 qstr, 2 varuint, 3 offset.
_FMT_MAGIC = const(932)
_EXTRA_MASK = const(158)


def f32bits(x):
    # Binary32 identity for the compiler's constant table.
    if _tag(x) != TAG_FLOAT:
        x = float(x)
    return _pay(x)


def _poke32(addr, val):
    if val < 0:
        val = val + (1 << 32)
    _poke8(addr, 0, val & 255)
    _poke8(addr, 1, (val >> 8) & 255)
    _poke8(addr, 2, (val >> 16) & 255)
    _poke8(addr, 3, (val >> 24) & 255)


def _qstate():
    st = _sysget(SR_FW5)
    if st is NULL:
        st = [{}, bytearray(), []]
        _sysset(SR_FW5, st)
    return st


def _heap_str(s):
    if _tag(s) == TAG_STR:
        return s
    n = _slen(s)
    r = _newstr(n)
    if n:
        _bcopy(r, 0, s, 0, n)
    return _fin(r, n)


def _q_add(st, s, nimg):
    desc = st[1]
    held = st[2]
    slot = len(held)
    need = (slot + 1) * 8
    while len(desc) < need:
        desc.append(0)
    base = _data(desc)
    h = _hash(s)
    if h is STOP:
        h = 1
    h = h & 65535
    if h == 0:
        h = 1
    ln = _slen(s)
    if ln > 65535:
        raise ValueError('qstr too long')
    ptr = _data(s)
    if not _ascii(s):
        ptr = ptr + (1 << 31)
    _poke32(base + slot * 8, h | (ln << 16))
    _poke32(base + slot * 8 + 4, ptr)
    held.append(s)
    _qxset(base, slot + 1)
    qid = nimg + slot
    st[0][s] = qid
    return qid


def _q_intern(s):
    st = _qstate()
    hit = _dget(st[0], s)
    if hit is not NULL:
        return hit
    nimg = _peek32(4 * HDR_QSTR_COUNT)
    i = 0
    while i < nimg:
        if _streq(s, _mk(TAG_QSTR, i)):
            st[0][s] = i
            return i
        i += 1
    return _q_add(st, _heap_str(s), nimg)


def _need(data, cur):
    i = cur[0]
    if i >= len(data):
        raise ValueError('truncated mpy')
    cur[0] = i + 1
    return data[i]


def _vint(data, cur):
    n = 0
    while True:
        b = _need(data, cur)
        n = (n << 7) | (b & 127)
        if (b & 128) == 0:
            return n


def _take(data, cur, n):
    i = cur[0]
    if n < 0 or i + n > len(data):
        raise ValueError('truncated mpy')
    cur[0] = i + n
    return data[i:i + n]


def _sig(data, cur):
    z = _need(data, cur)
    state = (z >> 3) & 15
    exc = (z >> 2) & 1
    scope = 0
    pos = z & 3
    kw = 0
    dpos = 0
    step = 0
    while z & 128:
        z = _need(data, cur)
        state = state | ((z & 48) << (2 * step))
        exc = exc | ((z & 2) << step)
        scope = scope | (((z & 64) >> 6) << step)
        pos = pos | ((z & 4) << step)
        kw = kw | (((z & 8) >> 3) << step)
        dpos = dpos | ((z & 1) << step)
        step += 1
    return [state + 1, exc, scope, pos, kw, dpos]


def _sz(data, cur):
    info = 0
    cells = 0
    step = 0
    while True:
        z = _need(data, cur)
        cells = cells | ((z & 1) << step)
        info = info | (((z & 126) >> 1) << (6 * step))
        if (z & 128) == 0:
            return [info, cells]
        step += 1


def _prelude(bc):
    cur = [0]
    sig = _sig(bc, cur)
    sz = _sz(bc, cur)
    info = sz[0]
    cells = sz[1]
    src_off = cur[0]
    nnames = 1 + sig[3] + sig[4]
    names = []
    i = 0
    while i < nnames:
        names.append(_vint(bc, cur))
        i += 1
    line_off = cur[0]
    line_end = src_off + info
    op_off = line_end + cells
    if line_off > line_end or op_off > len(bc):
        raise ValueError('bad prelude')
    return [sig[0], sig[1], sig[2], sig[3], sig[4], sig[5], info, cells, names, line_off, line_end, op_off]


def _static_fn():
    mod = _import('mpyc.qstrs', (), 0, NULL)
    return _ld(mod, 2)['static_text']


def _load_qstrs(data, cur, n, text_of):
    ids = []
    i = 0
    while i < n:
        head = _vint(data, cur)
        if head & 1:
            ids.append(_q_intern(text_of(head >> 1)))
        else:
            ln = head >> 1
            raw = _take(data, cur, ln)
            if _need(data, cur) != 0:
                raise ValueError('qstr missing NUL')
            ids.append(_q_intern(raw.decode('utf-8')))
        i += 1
    return ids


def _complex_text(text):
    if len(text) >= 2 and text[0] == '(' and text[len(text) - 1] == ')':
        text = text[1:len(text) - 1]
    return complex(text)


def _scalar(data, cur, kind):
    if kind == 1:
        return None
    if kind == 2:
        return False
    if kind == 3:
        return True
    if kind == 4:
        return Ellipsis
    if kind == 0:
        raise ValueError('fun table')
    if kind == 5 or kind == 6:
        n = _vint(data, cur)
        raw = _take(data, cur, n)
        if _need(data, cur) != 0:
            raise ValueError('const missing NUL')
        if kind == 5:
            return raw.decode('utf-8')
        return raw
    if kind == 7 or kind == 8 or kind == 9:
        n = _vint(data, cur)
        text = _take(data, cur, n).decode('utf-8')
        if kind == 7:
            return int(text)
        if kind == 8:
            return float(text)
        return _complex_text(text)
    raise ValueError('bad const')


def _load_obj(data, cur):
    stack = []
    while True:
        kind = _need(data, cur)
        if kind == 10:
            n = _vint(data, cur)
            if n:
                lst = []
                if stack:
                    stack[-1][0].append(lst)
                stack.append([lst, n])
                continue
            node = ()
        else:
            node = _scalar(data, cur, kind)
        if not stack:
            return node
        stack[-1][0].append(node)
        while stack and len(stack[-1][0]) >= stack[-1][1]:
            done = stack.pop()
            node = _tuple_of_list(done[0])
            if not stack:
                return node
            parent = stack[-1][0]
            parent[len(parent) - 1] = node


def _words(n, roots):
    if n <= 0:
        return 0
    w = _alloc(n, TAG_CONT, 0)
    roots.append(w)
    return w


def _fill_ids(w, ids):
    i = 0
    while i < len(ids):
        _st(w, i, ids[i])
        i += 1


def _const_base(objs, roots):
    n = len(objs)
    if n == 0:
        return 0
    t = _newtuple(n)
    i = 0
    while i < n:
        _st(t, 1 + i, objs[i])
        i += 1
    roots.append(t)
    return _pay(t) + 4


def _op_step(bc, ip):
    op = bc[ip]
    fmt = (_FMT_MAGIC >> (2 * (op >> 4))) & 3
    cur = ip + 1
    arg = 0
    if fmt == 1 or fmt == 2:
        arg = bc[cur] & 127
        while bc[cur] & 128:
            cur += 1
            arg = (arg << 7) | (bc[cur] & 127)
        cur += 1
    elif fmt == 3:
        if bc[cur] & 128:
            cur += 2
        else:
            cur += 1
    if (op & _EXTRA_MASK) == 0:
        cur += 1
    return [op, arg, cur]


def _local_count(bc, pre):
    # Same count the linker stores in the signature byte. n_state also
    # includes the compiler's stack budget, and that budget now lives in
    # the spill stack.
    n = pre[3] + pre[4]
    flags = pre[2]
    if flags & _SCOPE_VARARGS:
        n += 1
    if flags & _SCOPE_VARKW:
        n += 1
    ip = pre[11]
    end = len(bc)
    while ip < end:
        step = _op_step(bc, ip)
        op = step[0]
        idx = -1
        if op >= 176 and op <= 191:
            idx = op - 176
        elif op >= 192 and op <= 207:
            idx = op - 192
        elif op >= 36 and op <= 41:
            idx = step[1]
        if idx >= 0 and idx + 1 > n:
            n = idx + 1
        ip = step[2]
    off = pre[10]
    i = 0
    cells = pre[7]
    while i < cells:
        cell = bc[off + i]
        if cell + 1 > n:
            n = cell + 1
        i += 1
    return n


def _finish_rc(bc, pre, children, qids, roots, src_q, md_addr):
    base = _data(bc)
    names = pre[8]
    narg = len(names) - 1
    nw = _words(narg, roots)
    if nw != 0:
        i = 0
        while i < narg:
            _st(nw, i, qids[names[i + 1]])
            i += 1
    nc = pre[7]
    cw = _words(nc, roots)
    if cw != 0:
        i = 0
        off = pre[10]
        while i < nc:
            _st(cw, i, bc[off + i])
            i += 1
    ch = _words(len(children), roots)
    if ch != 0:
        i = 0
        while i < len(children):
            _st(ch, i, children[i])
            i += 1
    flags = _RC_FLAG_GENERATOR if (pre[2] & SCOPE_GENERATOR) else 0
    nloc = _local_count(bc, pre)
    rc = _alloc(12, TAG_CONT, 0)
    roots.append(rc)
    _st(rc, RC_OP_START, base + pre[11])
    _st(rc, RC_SIG, nloc | (pre[1] << 8) | (pre[2] << 16) | (flags << 24))
    _st(rc, RC_ARGS, pre[3] | (pre[4] << 8) | (pre[5] << 16) | (pre[7] << 24))
    _st(rc, RC_ARG_NAMES, _pay(nw) if nw != 0 else 0)
    _st(rc, RC_CELLS, _pay(cw) if cw != 0 else 0)
    _st(rc, RC_MODULE, md_addr)
    _st(rc, RC_CHILDREN, _pay(ch) if ch != 0 else 0)
    _st(rc, RC_NAME, qids[names[0]])
    _st(rc, RC_BC_START, base)
    _st(rc, RC_LINE_INFO, base + pre[9])
    _st(rc, RC_LINE_INFO_END, base + pre[10])
    _st(rc, RC_SOURCE_FILE, src_q)
    return _pay(rc)


def _load_tree(data, cur, qids, roots, src_q, md_addr):
    stack = []
    while True:
        head = _vint(data, cur)
        if (head & 3) != 0:
            raise ValueError('native code')
        has = (head >> 2) & 1
        bc = bytearray(_take(data, cur, head >> 3))
        roots.append(bc)
        pre = _prelude(bc)
        if has:
            n = _vint(data, cur)
            stack.append([[], n, bc, pre])
            if n:
                continue
            addr = _finish_rc(bc, pre, [], qids, roots, src_q, md_addr)
            stack.pop()
        else:
            addr = _finish_rc(bc, pre, [], qids, roots, src_q, md_addr)
        if not stack:
            return addr
        stack[-1][0].append(addr)
        while stack and len(stack[-1][0]) >= stack[-1][1]:
            frame = stack.pop()
            addr = _finish_rc(frame[2], frame[3], frame[0], qids, roots, src_q, md_addr)
            if not stack:
                return addr
            stack[-1][0].append(addr)


def _load_body(data, filename, roots):
    if len(data) < 4 or data[0] != 77 or data[1] != 6:
        raise ValueError('bad mpy')
    feat = data[2]
    if ((feat >> 2) & 47) != 0 or (feat & 2) != 0:
        raise ValueError('native mpy')
    if data[3] > 31:
        raise ValueError('small int')
    cur = [4]
    nq = _vint(data, cur)
    no = _vint(data, cur)
    qids = _load_qstrs(data, cur, nq, _static_fn())
    objs = []
    i = 0
    while i < no:
        objs.append(_load_obj(data, cur))
        i += 1
    qw = _words(nq, roots)
    if qw != 0:
        _fill_ids(qw, qids)
    cbase = _const_base(objs, roots)
    src_q = _q_intern(filename)
    md = _alloc(7, TAG_CONT, 0)
    roots.append(md)
    _st(md, MD_QSTRS, _pay(qw) if qw != 0 else 0)
    _st(md, MD_CONSTS, cbase)
    _st(md, MD_NAME, src_q)
    _st(md, MD_SOURCE_FILE, src_q)
    _st(md, MD_FLAGS, 0)
    _st(md, MD_PACKAGE, 0)
    rc = _load_tree(data, cur, qids, roots, src_q, _pay(md))
    _st(md, MD_RAW, rc)
    if cur[0] != len(data):
        raise ValueError('trailing mpy')
    fun = _alloc(8, TAG_OBJECT, 0)
    _st(fun, 0, OB_FUNCTION)
    _st(fun, 1, _ntype(T_FUNCTION))
    _st(fun, 2, rc)
    _st(fun, 3, NULL)
    _st(fun, 4, NULL)
    _st(fun, 5, NULL)
    _st(fun, 6, {})
    _st(fun, 7, _tuple_of_list(roots))
    return fun


def _load_mpy(data, filename):
    roots = []
    _sysset(SR_FW6, roots)
    try:
        return _load_body(data, filename, roots)
    finally:
        _sysset(SR_FW6, NULL)


def _compiler_open():
    mods = _sysget(SR_MODULES)
    if _dget(mods, 'mpyc.stages') is not NULL:
        return
    _import('mpyc', None, 0, NULL)
    _gc()
    _import('mpyc.stages', (), 0, NULL)
    _gc()


def _stages():
    mod = _import('mpyc.stages', (), 0, NULL)
    return _ld(mod, 2)


def _fail_compile(e):
    name = _tname(e)
    if name == 'ParseError' or name == 'CompileError':
        msg = _s(e.msg, ' (line ', _istr(e.line), ')')
        if name == 'ParseError' and e.kind == 'IndentationError':
            raise IndentationError(msg)
        raise SyntaxError(msg)
    raise e


def _check_mode(mode):
    # py/builtinevex.c accepts exec, eval, and single. flags and optimize
    # are in the signature and ignored.
    if mode != 'exec' and mode != 'eval' and mode != 'single':
        raise ValueError('bad compile mode')


def compile(*args, **kw):
    _check_args(args, kw, 3, 6)
    source = args[0]
    filename = args[1]
    mode = args[2]
    _check_mode(mode)
    if filename is None:
        filename = '<string>'
    if not _isstr(filename):
        filename = str(filename)
    if _tag(source) == TAG_BYTES or _isbarr(source):
        source = source.decode()
    if not _isstr(source):
        raise TypeError('compile source must be a str')
    _compiler_open()
    g = _stages()
    g['stage_begin']()
    fun = None
    data = None
    try:
        try:
            g['stage_parse'](source, filename, mode)
            source = None
            _gc()
            g['stage_scope']()
            _gc()
            g['stage_layout']()
            _gc()
            g['stage_write']()
            _gc()
            data = g['stage_encode']()
            _gc()
            fun = _load_mpy(data, filename)
            data = None
        except Exception as e:
            _fail_compile(e)
    finally:
        g['stage_end']()
    _gc()
    return fun


def _is_fun(x):
    return _tag(x) == TAG_OBJECT and _ld(x, 0) == OB_FUNCTION


def _as_code(code, mode):
    if _isstr(code):
        return compile(code, '<string>', mode)
    if _tag(code) == TAG_BYTES or _isbarr(code):
        return compile(code.decode(), '<string>', mode)
    if _is_fun(code):
        return code
    # mp_get_buffer_raise's text. An int has no buffer.
    raise TypeError('object with buffer protocol required')


def _exec_globals(args):
    # args[1] is the globals dict. None keeps the caller's globals.
    # A non-dict is a bare TypeError, the same as mp_raise_TypeError(NULL).
    if len(args) >= 2 and args[1] is not None:
        g = args[1]
        if not _isdict(g):
            raise TypeError()
        return g
    return NULL


def exec(*args, **kw):
    _check_args(args, kw, 1, 3)
    # _fget reads this frame's caller. A helper would see exec, whose globals
    # are the firmware ROM dict, and the store would raise.
    g = _exec_globals(args)
    if g is NULL:
        g = _fget(FR_GLOBALS)
        if g is NULL or not _isdict(g):
            g = {}
    if len(args) >= 3 and args[2] is not None:
        ns = args[2]
        if not _isdict(ns):
            raise TypeError()
    else:
        ns = g
    code = _as_code(args[0], 'exec')
    _st(code, 6, g)
    _callns(code, ns)
    return None


def eval(*args, **kw):
    _check_args(args, kw, 1, 3)
    g = _exec_globals(args)
    if g is NULL:
        g = _fget(FR_GLOBALS)
        if g is NULL or not _isdict(g):
            g = {}
    if len(args) >= 3 and args[2] is not None:
        ns = args[2]
        if not _isdict(ns):
            raise TypeError()
    else:
        ns = g
    code = _as_code(args[0], 'eval')
    _st(code, 6, g)
    return _callns(code, ns)
