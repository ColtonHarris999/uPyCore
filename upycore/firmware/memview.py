# memoryview (py/objarray.c), format 'B': a view of bytes, bytearray or str.
#
# [0] OB_MEMVIEW [1] type [2] base [3] byte offset [4] length [5] writable
#
# For a bytearray the base is its data block, not the bytearray, so a view
# keeps the buffer it was made from after the bytearray grows or shrinks,
# as MicroPython's raw items pointer does. For bytes and str the base is the
# object itself. Loads and stores go to _peek8/_poke8; only a bytearray view
# is writable. Subscripts reach these methods through the type dict, like
# any native object, so the core needs no new path.
from ._abi import *


def _ismv(x):
    return _tag(x) == TAG_OBJECT and _ld(x, 0) == OB_MEMVIEW


def _mv_make(base, off, n, rw):
    o = _alloc(6, TAG_OBJECT, 0)
    _st(o, 0, OB_MEMVIEW)
    _st(o, 1, _ntype(T_MEMORYVIEW))
    _st(o, 2, base)
    _st(o, 3, off)
    _st(o, 4, n)
    _st(o, 5, rw)
    return o


def _mv_ptr(base):
    # Something _peek8 and _poke8 take: a data block, or a str/bytes address.
    if _tag(base) == TAG_CONT:
        return base
    return _data(base)


def _mv_bytes(mv):
    # The viewed bytes, as a new bytes object.
    n = _ld(mv, 4)
    r = _strnew(n, TAG_BYTES)
    if n:
        p = _mv_ptr(_ld(mv, 2))
        off = _ld(mv, 3)
        d = _data(r)
        i = 0
        while i < n:
            _poke8(d, i, _peek8(p, off + i))
            i += 1
    return _strfin(r)


def _buf_bytes(x):
    # The bytes of a buffer-protocol object (bytes, bytearray, str,
    # memoryview), or NULL.
    t = _tag(x)
    if t == TAG_BYTES:
        return x
    if _isbarr(x):
        return _barr_bytes(x)
    if _ismv(x):
        return _mv_bytes(x)
    if _isstr(x):
        return x
    return NULL


def memoryview____new__(cls, *args, **kw):
    _check_args(args, kw, 1, 1)
    src = args[0]
    if _ismv(src):
        return _mv_make(_ld(src, 2), _ld(src, 3), _ld(src, 4), _ld(src, 5))
    if _isbarr(src):
        return _mv_make(_ld(src, 2), 0, _ld(src, 0), 1)
    if _tag(src) == TAG_BYTES or _isstr(src):
        return _mv_make(src, 0, _slen(src), 0)
    raise TypeError('object with buffer protocol required')


def _mv_index(mv, index):
    # mp_get_index: a small int or a bool; the message names memoryview.
    i = _word_index(mv, index)
    n = _ld(mv, 4)
    if i < 0:
        i += n
    if i < 0 or i >= n:
        raise IndexError('memoryview index out of range')
    return i


def _mv_slice(mv, sl):
    a, b, s = _slice_range(sl, _ld(mv, 4))
    if s != 1:
        raise NotImplementedError('only slices with step=1 (aka None) are supported')
    if b < a:
        b = a
    return a, b


def memoryview____getitem__(self, index):
    if _tag(index) == TAG_OBJECT and _ld(index, 0) == OB_SLICE:
        a, b = _mv_slice(self, index)
        return _mv_make(_ld(self, 2), _ld(self, 3) + a, b - a, _ld(self, 5))
    i = _mv_index(self, index)
    return _peek8(_mv_ptr(_ld(self, 2)), _ld(self, 3) + i)


def memoryview____setitem__(self, index, value):
    # array_subscr's order: deletion, then the index, then read-only, then
    # the value.
    if value is NULL:
        raise TypeError("'memoryview' object doesn't support item deletion")
    if _tag(index) == TAG_OBJECT and _ld(index, 0) == OB_SLICE:
        a, b = _mv_slice(self, index)
        if _tag(value) == TAG_BYTES or _isbarr(value) or _ismv(value):
            src = _buf_bytes(value)
        else:
            raise NotImplementedError('array/bytes required on right side')
        if not _ld(self, 5):
            _mv_readonly()
        n = _slen(src)
        if n != b - a:
            raise ValueError('lhs and rhs should be compatible')
        if n:
            p = _mv_ptr(_ld(self, 2))
            off = _ld(self, 3) + a
            d = _data(src)
            i = 0
            while i < n:
                _poke8(p, off + i, _peek8(d, i))
                i += 1
        return None
    i = _mv_index(self, index)
    if not _ld(self, 5):
        _mv_readonly()
    _poke8(_ld(self, 2), _ld(self, 3) + i, _byte_value(value))
    return None


def _mv_readonly():
    raise TypeError("'memoryview' object doesn't support item assignment")


def _mv_binop(op, a, b):
    # array_binary_op: equality compares the bytes of any buffer; the rest
    # is unsupported.
    if op == BINOP_EQUAL:
        other = _buf_bytes(b)
        if other is NULL:
            return False
        return _streq(_mv_bytes(a), other)
    return NULL
