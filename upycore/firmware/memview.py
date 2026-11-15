# memoryview (py/objarray.c): byte buffers and typed array storage.
#
# [0] OB_MEMVIEW [1] type [2] base [3] byte offset [4] element count
# [5] 0 read-only bytes, 1 writable bytes, 2 writable typed array
# [6] (typecode, width, pack, unpack) for a typed view
#
# For a bytearray the base is its data block, not the bytearray, so a view
# keeps the buffer it was made from after the bytearray grows or shrinks,
# as MicroPython's raw items pointer does. For bytes and str the base is the
# object itself. Array views use the array's bytearray backing block.
# Subscripts reach these methods through the type dict, like
# any native object, so the core needs no new path.
from ._abi import *


def _ismv(x):
    return _tag(x) == TAG_OBJECT and _ld(x, 0) == OB_MEMVIEW


def _mv_make(base, off, n, rw):
    o = _alloc(7 if rw == 2 else 6, TAG_OBJECT, 0)
    _st(o, 0, OB_MEMVIEW)
    _st(o, 1, _ntype(T_MEMORYVIEW))
    _st(o, 2, base)
    _st(o, 3, off)
    _st(o, 4, n)
    _st(o, 5, rw)
    return o


def _mv_typed(base, off, n, fmt):
    o = _mv_make(base, off, n, 2)
    _st(o, 6, fmt)
    return o


def _array_buffer(x):
    if _tag(x) != TAG_OBJECT or _ld(x, 0) != OB_INSTANCE:
        return NULL
    mod = _dget(_sysget(SR_MODULES), 'array')
    if mod is NULL or _tag(mod) != TAG_OBJECT or _ld(mod, 0) != OB_MODULE:
        return NULL
    buffer = _dget(_ld(mod, 2), '_buffer')
    if buffer is NULL:
        return NULL
    data = buffer(x)
    if _tag(data) != TAG_TUPLE or _ld(data, 0) != 6 or not _isbarr(data[0]):
        return NULL
    count = data[1]
    width = data[3]
    if _tag(count) != TAG_INT or count < 0 or _tag(width) != TAG_INT or width not in (1, 2, 4, 8):
        return NULL
    if count > _ld(data[0], 0) // width:
        return NULL
    return data


def _mv_width(mv):
    return _ld(mv, 6)[1] if _ld(mv, 5) == 2 else 1


def memoryview___upycore_typecode(self):
    return _ld(self, 6)[0] if _ld(self, 5) == 2 else 'B'


def _mv_ptr(base):
    # Something _peek8 and _poke8 take: a data block, or a str/bytes address.
    if _tag(base) == TAG_CONTINUE:
        return base
    return _data(base)


def _mv_bytes(mv):
    # The viewed bytes, as a new bytes object.
    n = _ld(mv, 4)
    if _ld(mv, 5) == 2:
        n *= _ld(mv, 6)[1]
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
    arr = _array_buffer(x)
    return _barr_bytes(arr[0]) if arr is not NULL else NULL


def memoryview____new__(cls, *args, **kw):
    _check_args(args, kw, 1, 1)
    src = args[0]
    if _ismv(src):
        rw = _ld(src, 5)
        if rw == 2:
            return _mv_typed(_ld(src, 2), _ld(src, 3), _ld(src, 4), _ld(src, 6))
        return _mv_make(_ld(src, 2), _ld(src, 3), _ld(src, 4), rw)
    if _isbarr(src):
        return _mv_make(_ld(src, 2), 0, _ld(src, 0), 1)
    if _tag(src) == TAG_BYTES or _isstr(src):
        return _mv_make(src, 0, _slen(src), 0)
    arr = _array_buffer(src)
    if arr is not NULL:
        data, count, code, width, pack, unpack = arr
        return _mv_typed(_ld(data, 2), 0, count, (code, width, pack, unpack))
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
        rw = _ld(self, 5)
        if rw == 2:
            fmt = _ld(self, 6)
            return _mv_typed(_ld(self, 2), _ld(self, 3) + a * fmt[1], b - a, fmt)
        return _mv_make(_ld(self, 2), _ld(self, 3) + a, b - a, rw)
    i = _mv_index(self, index)
    if _ld(self, 5) == 2:
        code, width, pack, unpack = _ld(self, 6)
        # A byte view lets the same unpacker read arrays and array views.
        off = _ld(self, 3) + i * width
        raw = _mv_make(_ld(self, 2), off, width, 1)
        return unpack(code, width, raw, 0)
    return _peek8(_mv_ptr(_ld(self, 2)), _ld(self, 3) + i)


def memoryview____setitem__(self, index, value):
    # array_subscr's order: deletion, then the index, then read-only, then
    # the value.
    if value is NULL:
        raise TypeError("'memoryview' object doesn't support item deletion")
    if _tag(index) == TAG_OBJECT and _ld(index, 0) == OB_SLICE:
        a, b = _mv_slice(self, index)
        width = _mv_width(self)
        if _tag(value) == TAG_BYTES or _isbarr(value):
            src_width = 1
            src = _buf_bytes(value)
        elif _ismv(value):
            src_width = _mv_width(value)
            src = _mv_bytes(value)
        else:
            arr = _array_buffer(value)
            if arr is NULL:
                raise NotImplementedError('array/bytes required on right side')
            src_width = arr[3]
            src = _barr_bytes(arr[0])
        if not _ld(self, 5):
            _mv_readonly()
        if width != src_width or _slen(src) != (b - a) * width:
            raise ValueError('lhs and rhs should be compatible')
        _mv_write(self, _ld(self, 3) + a * width, src)
        return None
    i = _mv_index(self, index)
    rw = _ld(self, 5)
    if rw == 0:
        _mv_readonly()
    if rw == 2:
        code, width, pack, unpack = _ld(self, 6)
        data = pack(code, width, value)
        if _tag(data) != TAG_BYTES or _slen(data) != width:
            raise ValueError('invalid packed array element')
        _mv_write(self, _ld(self, 3) + i * width, data)
    else:
        _poke8(_ld(self, 2), _ld(self, 3) + i, _byte_value(value))
    return None


def _mv_write(self, off, src):
    p = _mv_ptr(_ld(self, 2))
    d = _data(src)
    n = _slen(src)
    i = 0
    while i < n:
        _poke8(p, off + i, _peek8(d, i))
        i += 1
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
