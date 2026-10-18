# array('i'), array('I') and array('H'). The compiler keeps its stacks here
# instead of in a list of boxed ints.


class array:
    def __init__(self, typecode, init=()):
        if typecode == "i" or typecode == "I":
            self._w = 4
        elif typecode == "H":
            self._w = 2
        else:
            raise ValueError("bad typecode")
        self.typecode = typecode
        self._b = bytearray()
        self._n = 0
        if init:
            self.extend(init)

    def __len__(self):
        return self._n

    def append(self, v):
        self._b.extend(self._pack(v))
        self._n += 1

    def extend(self, it):
        for v in it:
            self.append(v)

    def __getitem__(self, index):
        if type(index) is slice:
            a, b = self._bounds(index)
            out = array(self.typecode)
            i = a
            while i < b:
                out.append(self._at(i))
                i += 1
            return out
        i = self._ix(index)
        return self._at(i)

    def __setitem__(self, index, value):
        if type(index) is slice:
            self._setslice(index, value)
            return
        i = self._ix(index)
        raw = self._pack(value)
        o = i * self._w
        j = 0
        while j < self._w:
            self._b[o + j] = raw[j]
            j += 1

    def __iter__(self):
        return _iter(self)

    def __repr__(self):
        parts = []
        i = 0
        while i < self._n:
            parts.append(str(self._at(i)))
            i += 1
        body = ", ".join(parts)
        return "array('" + self.typecode + "', [" + body + "])"

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
            raise ValueError("array slice step")
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
        mid = []
        if value is not None:
            for v in value:
                mid.append(v)
        out = array(self.typecode)
        i = 0
        while i < a:
            out.append(self._at(i))
            i += 1
        for v in mid:
            out.append(v)
        i = b
        while i < self._n:
            out.append(self._at(i))
            i += 1
        self._b = out._b
        self._n = out._n

    def _pack(self, v):
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
        o = i * self._w
        b = self._b
        v = b[o] | (b[o + 1] << 8)
        if self._w == 2:
            return v
        v |= (b[o + 2] << 16) | (b[o + 3] << 24)
        if self.typecode == "i" and v >= 2147483648:
            v -= 4294967296
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
