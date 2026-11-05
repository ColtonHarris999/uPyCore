# random for uPyCore: a bit-exact port of extmod/modrandom.c (yasmarang),
# frozen and linked only into programs that import it.
#
# The device has no entropy source, so like a MicroPython port without
# MICROPY_PY_RANDOM_SEED_INIT_FUNC it starts from the fixed yasmarang state
# and seed() / seed(None) raise ValueError('no default seed'). The unix
# oracle seeds itself on import, so only seeded sequences are comparable.
#
# All state is uint32. A 32x32 product would overflow the 64-bit int, so the
# multiply is split into 16-bit halves.

_pad = 0xeda4baba
_n = 69
_d = 233
_dat = 0


def _next():
    global _pad, _n, _d, _dat
    pad = _pad
    d = _d
    n = _n
    dn = (d * (n & 0xFFFF) + (((d * (n >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF
    pad = (pad + _dat + dn) & 0xFFFFFFFF
    pad = ((pad << 3) & 0xFFFFFFFF) | (pad >> 29)
    _n = pad | 2
    d ^= ((pad & 1) << 31) + (pad >> 1)
    dat = (_dat ^ pad ^ (d >> 8) ^ 1) & 255
    _pad = pad
    _d = d
    _dat = dat
    return pad ^ ((d << 5) & 0xFFFFFFFF) ^ (pad >> 18) ^ (dat << 1)


def _below(n):
    # yasmarang_randbelow; n is a nonzero uint32.
    mask = 1
    while (n & mask) < n:
        mask = (mask << 1) | 1
    r = _next() & mask
    while r >= n:
        r = _next() & mask
    return r


def _int(x):
    # mp_obj_get_int
    if isinstance(x, int):
        return int(x)
    raise TypeError("can't convert " + type(x).__name__ + " to int")


def seed(a=None):
    global _pad, _n, _d, _dat
    if a is None:
        raise ValueError('no default seed')
    _pad = _int(a) & 0xFFFFFFFF
    _n = 69
    _d = 233
    _dat = 0


def getrandbits(n):
    n = _int(n)
    if n > 32 or n < 0:
        raise ValueError('bits must be 32 or less')
    if n == 0:
        return 0
    return _next() & (0xFFFFFFFF >> (32 - n))


def randrange(start, stop=None, step=None):
    start = _int(start)
    if stop is None:
        if start > 0:
            return _below(start & 0xFFFFFFFF)
        raise ValueError()
    stop = _int(stop)
    if step is None:
        if start < stop:
            return start + _below((stop - start) & 0xFFFFFFFF)
        raise ValueError()
    step = _int(step)
    if step > 0:
        n = _tdiv(stop - start + step - 1, step)
    elif step < 0:
        n = _tdiv(stop - start + step + 1, step)
    else:
        raise ValueError()
    if n > 0:
        return start + step * _below(n & 0xFFFFFFFF)
    raise ValueError()


def _tdiv(a, b):
    # C division truncates toward zero.
    q = abs(a) // abs(b)
    if (a < 0) != (b < 0):
        return -q
    return q


def randint(a, b):
    a = _int(a)
    b = _int(b)
    if a <= b:
        return a + _below((b - a + 1) & 0xFFFFFFFF)
    raise ValueError()


def choice(seq):
    n = len(seq)
    if n > 0:
        return seq[_below(n)]
    raise IndexError()


def _float():
    # yasmarang_float: 23 random fraction bits in [1, 2), minus 1 (exact).
    return float(_next() & 0x7FFFFF) * 1.1920928955078125e-07


def random():
    return _float()


def uniform(a, b):
    a = _fl(a)
    b = _fl(b)
    return a + (b - a) * _float()


def _fl(x):
    if type(x) is float:
        return x
    if isinstance(x, int) or isinstance(x, float):
        return float(x)
    raise TypeError("can't convert " + type(x).__name__ + " to float")
