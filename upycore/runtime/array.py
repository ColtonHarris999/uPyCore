# Numeric arrays in the target's little-endian, 32-bit ABI.
# Keep the compiler's i/I/H paths specialized.


class array:
    def __init__(self, typecode, init=()):
        if typecode == "i" or typecode == "I":
            self._w = 4
        elif typecode == "H":
            self._w = 2
        else:
            # A negative width selects the generic conversion path.
            self._w = -_width(typecode)
        self.typecode = typecode
        self._b = bytearray()
        self._n = 0
        if init:
            kind = type(init)
            if kind is bytes or kind is bytearray:
                self._extend_raw(init)
            else:
                for value in init:
                    self.append(value)

    def __len__(self):
        return self._n

    def append(self, v):
        if self._w == 4:
            if self.typecode == "i":
                if v < -2147483648 or v > 2147483647:
                    raise OverflowError("signed int is out of range")
            elif v < 0 or v > 4294967295:
                raise OverflowError("unsigned int is out of range")
            self._b.append32(v)
            self._n += 1
            return
        self._b.extend(self._pack(v))
        self._n += 1

    def _extend_raw(self, raw):
        w = abs(self._w)
        n = len(raw) // w
        self._b.extend(raw[:n * w])
        self._n += n

    def extend(self, it):
        kind = type(it)
        if kind is not list and kind is not tuple:
            raw = _raw_buffer(it)
            if raw is not None:
                self._extend_raw(raw)
                return
        for v in it:
            self.append(v)

    def __add__(self, other):
        raw = _raw_buffer(other)
        if raw is None:
            raise TypeError("object with buffer protocol required")
        out = array(self.typecode, self._b)
        out._extend_raw(raw)
        return out

    def __iadd__(self, other):
        self.extend(other)
        return self

    def __contains__(self, value):
        if isinstance(value, int) or isinstance(value, float):
            raise NotImplementedError()
        return False

    def __eq__(self, other):
        return self._compare(other, 0)

    def __lt__(self, other):
        return self._compare(other, 1)

    def __le__(self, other):
        return self._compare(other, 2)

    def __gt__(self, other):
        return self._compare(other, 3)

    def __ge__(self, other):
        return self._compare(other, 4)

    def _compare(self, other, op):
        if isinstance(other, array):
            code = other.typecode
            raw = bytes(other._b)
        else:
            raw = _raw_buffer(other)
            if raw is None:
                return False
            code = other._upycore_typecode() if isinstance(other, memoryview) else 'B'
        own = self.typecode
        lhs = own.lower()
        rhs = code.lower()
        if lhs != rhs or lhs in 'fd' or (op and own == lhs and code == rhs):
            raise NotImplementedError()
        data = bytes(self._b)
        if op == 0:
            return data == raw
        if op == 1:
            return data < raw
        if op == 2:
            return data <= raw
        if op == 3:
            return data > raw
        return data >= raw

    def __getitem__(self, index):
        if type(index) is slice:
            a, b = self._bounds(index)
            w = abs(self._w)
            return array(self.typecode, self._b[a * w:b * w])
        i = self._ix(index)
        return self._at(i)

    def __setitem__(self, index, value):
        if type(index) is slice:
            self._setslice(index, value)
            return
        i = self._ix(index)
        raw = self._pack(value)
        w = len(raw)
        o = i * w
        j = 0
        while j < w:
            self._b[o + j] = raw[j]
            j += 1

    def __iter__(self):
        return _iter(self)

    def __repr__(self):
        head = "array('" + self.typecode + "'"
        if not self._n:
            return head + ")"
        parts = []
        i = 0
        while i < self._n:
            parts.append(repr(self._at(i)))
            i += 1
        return head + ", [" + ", ".join(parts) + "])"

    def _ix(self, index):
        i = index
        if i < 0:
            i += self._n
        if i < 0 or i >= self._n:
            raise IndexError("array index out of range")
        return i

    def _bounds(self, sl):
        n = self._n
        step = sl.step
        if step is None:
            step = 1
        if step != 1:
            raise NotImplementedError("only slices with step=1 (aka None) are supported")
        start = sl.start
        stop = sl.stop
        if start is None:
            start = 0
        elif start < 0:
            start += n
            if start < 0:
                start = 0
        elif start > n:
            start = n
        if stop is None:
            stop = n
        elif stop < 0:
            stop += n
            if stop < 0:
                stop = 0
        elif stop > n:
            stop = n
        return start, stop

    def _setslice(self, sl, value):
        a, b = self._bounds(sl)
        b = max(a, b)
        w = abs(self._w)
        if isinstance(value, array):
            width = abs(value._w)
        elif isinstance(value, memoryview):
            width = _width(value._upycore_typecode())
        elif isinstance(value, (bytes, bytearray)):
            width = 1
        else:
            raise NotImplementedError("array/bytes required on right side")
        if width != w:
            raise ValueError("lhs and rhs should be compatible")
        raw = _raw_buffer(value)
        self._b[a * w:b * w] = raw
        self._n += len(raw) // w - (b - a)

    def _pack(self, v):
        if self._w < 0:
            return _pack_format(self.typecode, -self._w, v)
        if self._w == 2:
            if v < 0 or v > 65535:
                raise OverflowError("unsigned short is out of range")
            return bytes((v & 255, (v >> 8) & 255))
        if self.typecode == "i":
            if v < -2147483648 or v > 2147483647:
                raise OverflowError("signed int is out of range")
            if v < 0:
                v += 4294967296
        elif v < 0 or v > 4294967295:
            raise OverflowError("unsigned int is out of range")
        return bytes((v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255))

    def _at(self, i):
        w = self._w
        b = self._b
        if w < 0:
            return _unpack_format(self.typecode, -w, b, i * -w)
        o = i * w
        v = b[o] | (b[o + 1] << 8)
        if w == 2:
            return v
        v |= (b[o + 2] << 16) | (b[o + 3] << 24)
        if v >= 2147483648 and self.typecode == "i":
            return v - 4294967296
        return v


class _iter:
    def __init__(self, a):
        self._a = a
        self._i = 0

    def __next__(self):
        if self._i >= len(self._a):
            raise StopIteration
        v = self._a[self._i]
        self._i += 1
        return v


def _width(code):
    if type(code) is str and len(code) == 1:
        if code in 'bB':
            return 1
        if code in 'hH':
            return 2
        if code in 'iIlLf':
            return 4
        if code in 'qQd':
            return 8
    raise ValueError("bad typecode")


def _buffer(obj):
    # Used by firmware to recognize this frozen module's arrays.
    if isinstance(obj, array):
        return obj._b, obj._n, obj.typecode, abs(obj._w), _pack_format, _unpack_format
    return None


def _raw_buffer(obj):
    if isinstance(obj, array):
        return bytes(obj._b)
    if isinstance(obj, (bytes, bytearray, memoryview, str)):
        return bytes(memoryview(obj)) if isinstance(obj, str) else bytes(obj)
    return None


def _pack_format(code, width, value):
    if code == 'f' or code == 'd':
        if isinstance(value, str):
            raise TypeError("can't convert str to float")
        v = f32bits(float(value)) & 0xffffffff
        if code == 'd':
            exp = (v >> 23) & 255
            frac = v & 0x7fffff
            if exp == 255:
                exp = 2047
            elif exp:
                exp += 896
            elif frac:
                exp = 897
                while frac < 0x800000:
                    frac <<= 1
                    exp -= 1
                frac &= 0x7fffff
            # Keep the packed value signed to fit the target's int64.
            sign = (-9223372036854775807 - 1) if v >> 31 else 0
            v = sign | (exp << 52) | (frac << 29)
    else:
        if type(value) is bool:
            value = int(value)
        if not isinstance(value, int):
            raise TypeError("array element must be an integer")
        signed = code in 'bhilq'
        bits = width * 8
        if width == 8:
            valid = signed or value >= 0
        elif signed:
            bound = 1 << (bits - 1)
            valid = -bound <= value < bound
        else:
            valid = 0 <= value < (1 << bits)
        if not valid:
            raise OverflowError("integer out of range")
        v = value
    return bytes([(v >> (8 * i)) & 255 for i in range(width)])


def _unpack_format(code, width, data, offset):
    if code == 'd':
        high = data[offset + 7]
        v = high << 56 if high < 128 else (high - 256) << 56
        for i in range(7):
            v |= data[offset + i] << (8 * i)
        return _double_to_float(v)

    signed = code in 'bhilq'
    high = data[offset + width - 1]
    if high >= 128:
        if signed:
            high -= 256
        elif code == 'Q':
            raise OverflowError("long long overflow")
    v = high << (8 * (width - 1))
    for i in range(width - 1):
        v |= data[offset + i] << (8 * i)
    if code == 'f':
        return float._from_bits(v)
    return v


def _double_to_float(v):
    exp = (v >> 52) & 2047
    frac = v & 0xfffffffffffff
    sign = (v >> 32) & 0x80000000
    if exp == 2047:
        return float._from_bits(sign | 0x7f800000 | (1 if frac else 0))
    if exp < 873:
        return float._from_bits(sign)
    if exp > 1150:
        return float._from_bits(sign | 0x7f800000)
    exp -= 896
    shift = 29 + max(0, 1 - exp)
    mantissa = frac | 0x10000000000000
    rounded = mantissa >> shift
    remainder = mantissa & ((1 << shift) - 1)
    half = 1 << (shift - 1)
    if remainder > half or (remainder == half and rounded & 1):
        rounded += 1
    # Carry out of the significand rounds into the next exponent.
    return float._from_bits(sign | ((max(0, exp - 1) << 23) + rounded))
