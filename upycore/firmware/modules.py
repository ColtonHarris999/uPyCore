# sys, gc, micropython, and import.
from ._abi import *


def _sys_exit(code=None):
    raise SystemExit(code)


def _sys_print_exception(exc, file=None):
    _print_tb(exc, NULL if file is None else file)
    return None


def _gc_collect():
    if _sysget(SR_FW4) is False:
        return None
    _gc()
    return None


def _gc_enable():
    _sysset(SR_FW4, True)
    return None


def _gc_disable():
    _sysset(SR_FW4, False)
    return None


def _gc_isenabled():
    return _sysget(SR_FW4) is not False


def _gc_mem_free():
    return _gcinfo(0)


def _gc_mem_alloc():
    return _gcinfo(1) - _gcinfo(0)


def _gc_threshold(amount=_MISSING):
    return -1


def _mp_const(x):
    return x


def _mp_opt(level=_MISSING):
    return 0


def _mp_total():
    return _gcinfo(1)


def _mp_current():
    return _gc_mem_alloc()


def _mp_peak():
    return _gc_mem_alloc()


def _mp_info():
    return None


def _mp_stack():
    return 0


def _mp_lock():
    return None


def _mp_unlock():
    return None


def _mp_kbd(i):
    return None


def _mp_qstr():
    return (0, 0)


def _mp_sched(func, arg):
    func(arg)
    return None


def _build_sys(filename):
    impl = _mk_module('', {
        'name': 'upycore',
        'version': (1, 29, 0, ''),
        '_machine': 'upycore',
        '_mpy': 1798,
    })
    g = {
        'argv': [filename],
        'byteorder': 'little',
        'maxsize': 1073741823 * 2 + 1,
        'platform': 'upycore',
        'version': '3.4.0; MicroPython 062cf49b48 on 2026-10-14',
        'version_info': (3, 4, 0),
        'implementation': impl,
        'modules': _sysget(SR_MODULES),
        'path': ['.', '.frozen'],
        'executable': '',
        'exit': _sys_exit,
        'print_exception': _sys_print_exception,
        'exc_info': _sys_exc_info,
    }
    # Five words: the extra one is the builtins module singleton. Firmware
    # globals are a ROM dict, so that object cannot be stored by name, and
    # it does not take a sysroot slot. SR_FW7 is the override dict only.
    m = _alloc(5, TAG_OBJECT, 0)
    _st(m, 0, OB_MODULE)
    _st(m, 1, _ntype(T_MODULE))
    _st(m, 2, g)
    _st(m, 3, 'sys')
    return m


def _sys_exc_info():
    return (None, None, None)


def _build_gc():
    return _mk_module('gc', {
        'collect': _gc_collect,
        'disable': _gc_disable,
        'enable': _gc_enable,
        'isenabled': _gc_isenabled,
        'mem_alloc': _gc_mem_alloc,
        'mem_free': _gc_mem_free,
        'threshold': _gc_threshold,
    })


def _build_mp():
    return _mk_module('micropython', {
        'const': _mp_const,
        'opt_level': _mp_opt,
        'mem_total': _mp_total,
        'mem_current': _mp_current,
        'mem_peak': _mp_peak,
        'mem_info': _mp_info,
        'stack_use': _mp_stack,
        'heap_lock': _mp_lock,
        'heap_unlock': _mp_unlock,
        'kbd_intr': _mp_kbd,
        'qstr_info': _mp_qstr,
        'schedule': _mp_sched,
    })


def _dot_parts(name):
    out = []
    start = 0
    n = _slen(name)
    i = 0
    while i <= n:
        if i == n or _byte(name, i) == 46:
            if i > start:
                out.append(_substr(name, start, i, TAG_STR))
            start = i + 1
        i += 1
    return out


# Bit 1 of a module descriptor's flags word. The linker sets it for __init__.py.
_MD_FLAG_PACKAGE = 2


def _is_builtins_dict(d):
    return d is _BUILTINS


def _builtins_module():
    # Same object on every import. Its globals are the ROM builtins dict.
    sysm = _sysget(SR_FW1)
    hit = _ld(sysm, 4)
    if hit is not NULL:
        return hit
    mod = _mk_module('builtins', _BUILTINS)
    _st(sysm, 4, mod)
    return mod


def _builtins_store(name, value):
    # First store or delete allocates an empty override. A delete removes
    # the key from that dict and does not write NULL over the ROM entry.
    d = _sysget(SR_FW7)
    if d is NULL:
        d = {}
        _sysset(SR_FW7, d)
    if value is NULL:
        del d[name]
    else:
        d[name] = value
    return None


def _nonext_builtin(name):
    if _streq(name, 'sys') or _streq(name, 'usys'):
        return _sysget(SR_FW1)
    if _streq(name, 'gc'):
        return _sysget(SR_FW2)
    if _streq(name, 'micropython'):
        return _sysget(SR_FW3)
    if _streq(name, 'builtins'):
        return _builtins_module()
    # A leading u aliases an extensible native module. One character does not.
    # usys was handled above; it is not this prefix rule.
    if _slen(name) > 1 and _byte(name, 0) == 117:
        nat = _dget(_NATIVE_MODULES, _substr(name, 1, _slen(name), TAG_STR))
        if nat is not NULL:
            return nat
    return NULL


def _import_path():
    sysm = _sysget(SR_FW1)
    if sysm is NULL:
        return NULL
    return _dget(_ld(sysm, 2), 'path')


def _path_nonempty(path):
    if path is NULL:
        return False
    if _islist(path) or _tag(path) == TAG_TUPLE:
        return len(path) > 0
    raise TypeError(_s("object '", _tname(path), "' isn't a tuple or list"))


def _frozen_root(root):
    return _isstr(root) and (_streq(root, '.') or _streq(root, '.frozen'))


def _rooted(root, comp):
    if _slen(root) == 0:
        return comp
    return _cat(_cat(root, '/'), comp)


def _relative_name(name, level, globs):
    # evaluate_relative_import: __name__ only, and a package drops one level.
    if globs is NULL or not _isdict(globs):
        raise ImportError("can't perform relative import")
    cur = _dget(globs, '__name__')
    if cur is NULL or not _isstr(cur):
        raise ImportError("can't perform relative import")
    if _streq(cur, '__main__'):
        alt = _dget(globs, '__main__')
        if alt is not NULL and _isstr(alt):
            cur = alt
    n = _slen(cur)
    p = n
    left = level
    if _dget(globs, '__path__') is not NULL:
        left -= 1
    while left > 0 and p > 0:
        p -= 1
        if _byte(cur, p) == 46:
            left -= 1
    if p == 0:
        raise ImportError("can't perform relative import")
    base = _substr(cur, 0, p, TAG_STR)
    if name is NULL or not _isstr(name) or _slen(name) == 0:
        return base
    return _cat(_cat(base, '.'), name)


def _resolve_name(name, level, globs):
    if level < 0:
        raise ValueError()
    if level:
        name = _relative_name(name, level, globs)
    if name is NULL or not _isstr(name) or _slen(name) == 0:
        raise ValueError()
    return name


def _drop_module(name):
    mods = _sysget(SR_MODULES)
    hit = _lookup(mods, name)
    if hit is STOP:
        if _map_find(mods, name, False) < 0:
            return None
    elif hit is NULL:
        return None
    del mods[name]
    return None


def _exec_frozen(full, fr, pathstr):
    g = {'__name__': full}
    g['__file__'] = _mk(TAG_QSTR, _peek32(fr + 4 * MD_SOURCE_FILE))
    if _peek32(fr + 4 * MD_FLAGS) & _MD_FLAG_PACKAGE:
        g['__path__'] = pathstr
    mod = _mk_module(full, g)
    mods = _sysget(SR_MODULES)
    mods[full] = mod
    try:
        _callns(fr, g)
    except BaseException:
        _drop_module(full)
        raise
    return mod


def _load_top(full, comp, path):
    builtin = _nonext_builtin(comp)
    if builtin is not NULL:
        return builtin, False
    if _islist(path) or _tag(path) == TAG_TUPLE:
        for root in path:
            if not _frozen_root(root):
                continue
            fr = _dget(_FROZEN, full)
            if fr is NULL:
                continue
            return _exec_frozen(full, fr, _rooted(root, comp)), True
    nat = _dget(_NATIVE_MODULES, comp)
    if nat is not NULL:
        return nat, False
    raise ImportError(_s("no module named '", full, "'"))


def _load_child(full, comp, parent):
    g = _ld(parent, 2)
    ppath = _dget(g, '__path__')
    if ppath is NULL:
        raise ImportError(_s("no module named '", full, "'"))
    fr = _dget(_FROZEN, full)
    if fr is NULL:
        raise ImportError(_s("no module named '", full, "'"))
    if _isstr(ppath) and _slen(ppath):
        pathstr = _cat(_cat(ppath, '/'), comp)
    else:
        pathstr = comp
    return _exec_frozen(full, fr, pathstr), True


def _load_one(full, comp, parent):
    # A non-empty sys.path consults the cache first. An empty path skips
    # it so a builtin wins over a previously loaded module of the same name.
    path = _import_path()
    if _path_nonempty(path):
        hit = _dget(_sysget(SR_MODULES), full)
        if hit is not NULL:
            return hit, False
    if parent is NULL:
        return _load_top(full, comp, path)
    return _load_child(full, comp, parent)


def _load_import(name, fromlist, level, globs):
    # fromlist None returns the top component. () and True return the leaf.
    name = _resolve_name(name, level, globs)
    parts = _dot_parts(name)
    if not parts:
        raise ValueError()
    top = NULL
    parent = NULL
    acc = ''
    i = 0
    n = len(parts)
    while i < n:
        comp = parts[i]
        if i == 0:
            full = comp
        else:
            full = _cat(_cat(acc, '.'), comp)
        mod, created = _load_one(full, comp, parent)
        # Attach only a module this call created, and only after its body.
        if parent is not NULL and created:
            _ld(parent, 2)[comp] = mod
        if top is NULL:
            top = mod
        parent = mod
        acc = full
        i += 1
    if fromlist is None:
        return top
    return parent


def _import(name, fromlist, level, globs):
    ov = _sysget(SR_FW7)
    if ov is not NULL:
        hook = _dget(ov, '__import__')
        if hook is not NULL:
            return hook(name, globs, None, fromlist, level)
    return _load_import(name, fromlist, level, globs)


def __import__(name, globals=None, locals=None, fromlist=None, level=0):
    # ROM builtins entry. Calls the loader, not _import, so an override
    # that invokes the original builtin does not recurse.
    g = globals if _isdict(globals) else {}
    return _load_import(name, fromlist, level, g)


def _import_from(mod, name):
    hit = _module_attr(mod, name)
    if hit is not NULL:
        return hit
    g = _ld(mod, 2)
    if _dget(g, '__path__') is NULL:
        raise ImportError(_s("can't import name ", name))
    mname = _dget(g, '__name__')
    if mname is NULL or not _isstr(mname):
        mname = _ld(mod, 3)
    # mp_import_from calls mp_import_name. fromlist True reaches an override.
    # Do not catch ImportError: a missing submodule keeps no module named.
    return _import(_cat(_cat(mname, '.'), name), True, 0, NULL)


def _import_star(mod, loc):
    try:
        all_ = _module_attr(mod, '__all__')
    except AttributeError:
        all_ = NULL
    if all_ is not NULL:
        if not (_islist(all_) or _tag(all_) == TAG_TUPLE):
            raise TypeError(_s("object '", _tname(all_), "' isn't a tuple or list"))
        for name in all_:
            if not _isstr(name):
                raise TypeError(_s("can't convert '", _tname(name), "' object to str implicitly"))
            loc[name] = _import_from(mod, name)
        return None
    g = _ld(mod, 2)
    for k in g:
        if _slen(k) and _byte(k, 0) != 95:
            loc[k] = g[k]
    return None
