# io for uPyCore: StringIO, BytesIO and IOBase, frozen and linked only into
# programs that import it. Follows py/objstringio.c: both classes keep a
# byte buffer and a byte position; StringIO converts to and from UTF-8 str.
# print(file=...) calls write(), so a StringIO collects print output.

open = open


class IOBase:
    # Base for user streams. The device has no C stream protocol, so this
    # only gives subclasses the name.
    pass


class _BufIO:
    def __init__(self, init=None):
        self._pos = 0
        if init is None or isinstance(init, int):
            self._b = bytearray()
        else:
            self._b = bytearray(self._bytes(init))

    def _open(self):
        b = self._b
        if b is None:
            raise ValueError('I/O operation on closed file')
        return b

    def _bytes(self, s):
        if isinstance(s, str):
            return s.encode()
        return s

    def write(self, s):
        b = self._open()
        data = self._bytes(s)
        n = len(data)
        pos = self._pos
        end = len(b)
        if pos == end:
            b.extend(data)
        else:
            if pos > end:
                b.extend(bytes(pos - end))
            b[pos:pos + n] = data
        self._pos = pos + n
        return n

    def _take(self, size):
        b = self._open()
        pos = self._pos
        end = len(b)
        if pos >= end:
            return b''
        if size is None or size < 0 or pos + size > end:
            size = end - pos
        self._pos = pos + size
        return bytes(b[pos:pos + size])

    def read(self, size=-1):
        return self._out(self._take(size))

    def readline(self, size=-1):
        b = self._open()
        pos = self._pos
        i = b.find(b'\n', pos)
        n = len(b) - pos if i < 0 else i + 1 - pos
        if size is not None and 0 <= size < n:
            n = size
        return self._out(self._take(n))

    def readinto(self, buf):
        data = self._take(len(buf))
        n = len(data)
        buf[0:n] = data
        return n

    def seek(self, offset, whence=0):
        b = self._open()
        if whence == 1:
            ref = self._pos
        elif whence == 2:
            ref = len(b)
        else:
            ref = 0
        new = ref + offset
        if new < 0:
            if whence == 0:
                raise OSError(22)
            new = 0
        self._pos = new
        return new

    def tell(self):
        self._open()
        return self._pos

    def flush(self):
        self._open()

    def close(self):
        self._b = None

    def getvalue(self):
        return self._out(bytes(self._open()))

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class StringIO(_BufIO):
    def _out(self, data):
        return data.decode()


class BytesIO(_BufIO):
    def _out(self, data):
        return data
