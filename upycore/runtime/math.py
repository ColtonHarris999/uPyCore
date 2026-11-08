# math for uPyCore: binary32, frozen, linked only into programs that import it.
#
# The kernels are ports of the pinned tree's lib/libm (fdlibm/musl float
# routines, the ones bare-metal MicroPython ports use), with the same
# operation order. The FPU rounds +, -, *, / to binary32 exactly, so each
# step matches the C code. Float constants are the exact decimal value of
# the C constant's bit pattern. sqrt is correctly rounded (x ** 0.5 on the
# FPU, checked against an exact integer square root). Arguments larger
# than 2^7*pi/2 are reduced exactly with 64-bit integer arithmetic over the
# same 2/pi bits that ef_rem_pio2.c uses, instead of __kernel_rem_pio2f.
#
# The unix oracle calls the host libm, so sin/cos/tan/exp/log can differ
# from it in the last bit. Errors follow py/modmath.c: a NaN from a non-NaN
# argument, or an infinity from a finite one, is ValueError("math domain
# error").
#
# Not implemented yet: acos asin atan atan2 acosh asinh atanh cosh sinh tanh
# expm1 erf erfc gamma lgamma fmod.


def _mkp2():
    t = [0.0] * 277
    v = 1.0
    for k in range(128):
        t[149 + k] = v
        v = v * 2.0
    v = 1.0
    for k in range(1, 150):
        v = v * 0.5
        t[149 - k] = v
    return tuple(t)


# _P2[k + 149] is 2.0 ** k for -149 <= k <= 127, built by exact doubling.
_P2 = _mkp2()
inf = _P2[276] * 2.0
nan = inf - inf
pi = 3.1415927410125732
e = 2.7182817459106445
tau = 6.2831854820251465
_DEG = 0.01745329238474369
_RAD = 57.29578

# 2/pi as 31-bit windows: _W31[k - 1] holds bits k .. k+30 (bit k weighs
# 2^-k), from the two_over_pi bytes of ef_rem_pio2.c. A constant table, so a
# window is one load instead of a bit loop.
_W31 = (
    1367130551, 586777454, 1173554908, 199626169, 399252338, 798504676,
    1597009353, 1046535059, 2093070119, 2038656590, 1929829532, 1712175417,
    1276867186, 406250724, 812501448, 1625002897, 1102522146, 57560644,
    115121288, 230242576, 460485152, 920970305, 1841940610, 1536397573,
    925311498, 1850622997, 1553762346, 960041044, 1920082089, 1692680530,
    1237877413, 328271178, 656542356, 1313084713, 478685779, 957371559,
    1914743119, 1682002591, 1216521535, 285559423, 571118846, 1142237692,
    136991736, 273983472, 547966945, 1095933890, 44384132, 88768265,
    177536531, 355073063, 710146126, 1420292253, 693100858, 1386201717,
    624919786, 1249839573, 352195499, 704390999, 1408781999, 670080351,
    1340160702, 532837757, 1065675514, 2131351028, 2115218408, 2082953169,
    2018422691, 1889361735, 1631239823, 1114995999, 82508350, 165016701,
    330033402, 660066805, 1320133610, 492783572, 985567145, 1971134291,
    1794784934, 1442086221, 736688794, 1473377588, 799271529, 1598543059,
    1049602470, 2099204941, 2050926235, 1954368823, 1761253998, 1375024349,
    602565051, 1205130103, 262776558, 525553116, 1051106232, 2102212464,
    2056941280, 1966398912, 1785314177, 1423144707, 698805766, 1397611533,
    647739419, 1295478838, 443474029, 886948059, 1773896118, 1400308589,
    653133531, 1306267062, 465050476, 930100952, 1860201905, 1572920162,
    998356677, 1996713354, 1845943060, 1544402473, 941321298, 1882642597,
    1617801546, 1088119445, 28755243, 57510486, 115020972, 230041945,
    460083891, 920167782, 1840335564, 1533187481, 918891314, 1837782628,
    1528081609, 908679571, 1817359143, 1487234639, 826985630, 1653971260,
    1160458872, 173434097, 346868194, 693736388, 1387472776, 627461904,
    1254923809, 362363971, 724727943, 1449455886, 751428124, 1502856249,
    858228850, 1716457700, 1285431752, 423379856, 846759712, 1693519425,
    1239555202, 331626756, 663253512, 1326507024, 505530400, 1011060801,
)
_NPIO2_HW = (
    0x3fc90f00, 0x40490f00, 0x4096cb00, 0x40c90f00, 0x40fb5300, 0x4116cb00,
    0x412fed00, 0x41490f00, 0x41623100, 0x417b5300, 0x418a3a00, 0x4196cb00,
    0x41a35c00, 0x41afed00, 0x41bc7e00, 0x41c90f00, 0x41d5a000, 0x41e23100,
    0x41eec200, 0x41fb5300, 0x4203f200, 0x420a3a00, 0x42108300, 0x4216cb00,
    0x421d1400, 0x42235c00, 0x4229a500, 0x422fed00, 0x42363600, 0x423c7e00,
    0x4242c700, 0x42490f00,
)


def _f(x):
    # mp_obj_get_float: bool, int, float, or __float__.
    t = type(x)
    if t is float:
        return x
    # bool is not an int subclass on MicroPython, so it is named here.
    if t is bool or isinstance(x, int) or isinstance(x, float):
        return float(x)
    m = getattr(t, '__float__', None)
    if m is not None:
        r = m(x)
        if isinstance(r, float):
            return r
    raise TypeError("can't convert " + t.__name__ + " to float")


def _err():
    raise ValueError('math domain error')


def _fromb(b):
    # Binary32 bits to float, for finite values. m * 2**k is exact.
    ex = (b >> 23) & 255
    m = b & 0x7FFFFF
    if ex:
        r = float(m | 0x800000) * _P2[ex - 1]
    else:
        r = float(m) * _P2[0]
    if b & 0x80000000:
        return -r
    return r


def _scalbn(y, n):
    # musl scalbnf.
    if n > 127:
        y = y * _P2[276]
        n -= 127
        if n > 127:
            y = y * _P2[276]
            n -= 127
            if n > 127:
                n = 127
    elif n < -126:
        y = y * _P2[47]
        n += 102
        if n < -126:
            y = y * _P2[47]
            n += 102
            if n < -126:
                n = -126
    return y * _P2[n + 149]


# ---------------------------------------------------------------------------
# sqrt: correctly rounded, from the FPU's power unit.

def sqrt(x):
    x = _f(x)
    if x > 0.0:
        if x == inf:
            return x
        # The FPU sends ** 0.5 to the divider's correctly rounded binary64
        # square root (upycore_fpu.sv, S_POW_SQRT); rounding that to binary32
        # is correctly rounded too (53 >= 2*24+2).
        return x ** 0.5
    if x == 0.0 or x != x:
        return x
    _err()


# ---------------------------------------------------------------------------
# sin, cos, tan

def _ksin(x, y, iy):
    # kf_sin.c
    if -7.450581e-09 < x < 7.450581e-09:
        return x
    z = x * x
    v = z * x
    r = 0.008333333767950535 + z * (-0.00019841270113829523 + z * (2.7557314297155244e-06 + z * (-2.5050759688838298e-08 + z * 1.5896910177115586e-10)))
    if iy == 0:
        return x + v * (-0.1666666716337204 + z * r)
    return x - ((z * (0.5 * y - v * r) - y) - v * -0.1666666716337204)


def _kcos(x, y):
    # kf_cos.c
    ax = abs(x)
    if ax < 7.450581e-09:
        return 1.0
    z = x * x
    r = z * (0.0416666679084301 + z * (-0.0013888889225199819 + z * (2.4801587642286904e-05 + z * (-2.7557314297155244e-07 + z * (2.087572337217125e-09 + z * -1.135964759757524e-11)))))
    if ax < 0.30000001192092896:
        return 1.0 - (0.5 * z - (z * r - x * y))
    if ax > 0.78125:
        qx = 0.28125
    else:
        qx = ax * 0.25
    hz = 0.5 * z - qx
    a = 1.0 - qx
    return a - (hz - (z * r - x * y))


_T = (
    0.3333333432674408, 0.13333334028720856, 0.05396825447678566,
    0.021869488060474396, 0.008863239549100399, 0.0035920790396630764,
    0.00145620945841074, 0.0005880412645637989, 0.0002464631397742778,
    7.817944424459711e-05, 7.14072521077469e-05, -1.8558637748355977e-05,
    2.5907306e-05,
)


def _ktan(x, y, iy):
    # kf_tan.c
    T = _T
    hx = f32bits(x)
    ix = hx & 0x7FFFFFFF
    if ix < 0x31800000:
        if ix == 0 and iy == -1:
            return 1.0 / abs(x)
        if iy == 1:
            return x
        return -1.0 / x
    big = ix >= 0x3f2ca140
    if big:
        if hx & 0x80000000:
            x = -x
            y = -y
        z = 0.7853981256484985 - x
        w = 3.774894707930798e-08 - y
        x = z + w
        y = 0.0
    z = x * x
    w = z * z
    r = T[1] + w * (T[3] + w * (T[5] + w * (T[7] + w * (T[9] + w * T[11]))))
    v = z * (T[2] + w * (T[4] + w * (T[6] + w * (T[8] + w * (T[10] + w * T[12])))))
    s = z * x
    r = y + z * (s * (r + v) + y)
    r += T[0] * s
    w = x + r
    if big:
        v = float(iy)
        t = v - 2.0 * (x - (w * w / (w + v) - r))
        if hx & 0x80000000:
            return -t
        return t
    if iy == 1:
        return w
    z = _fromb(f32bits(w) & 0xfffff000)
    v = r - (z - x)
    a = -1.0 / w
    t = _fromb(f32bits(a) & 0xfffff000)
    s = 1.0 + t * z
    return t + a * (s + t * v)


def _tpbits(k0, n):
    # Bits k0 .. k0+n-1 of 2/pi (n <= 31); bits before bit 1 are zero.
    if k0 >= 1:
        return _W31[k0 - 1] >> (31 - n)
    return _W31[0] >> (31 - n + 1 - k0)


def _rem_big(ax):
    # |x| > 2^7*pi/2. x = m * 2^ex exactly. Q = floor(x * 2/pi * 2^58)
    # mod 2^61 from three limbs of the 2/pi window; bits that only add
    # multiples of 8 are skipped, bits past the window add under 2^-64.
    b = f32bits(ax)
    ex = (b >> 23) - 150
    m = (b & 0x7FFFFF) | 0x800000
    k0 = ex - 2
    a = m * _tpbits(k0 + 60, 31)
    q = ((m * _tpbits(k0, 29)) & 0x1FFFFFFF) << 32
    q = (q + ((m * _tpbits(k0 + 29, 31)) << 1) + (a >> 30)) & 0x1FFFFFFFFFFFFFFF
    n = (q + 0x200000000000000) >> 58
    fr = q - (n << 58)
    neg = fr < 0
    if neg:
        fr = -fr
    if fr == 0:
        return n, 0.0, 0.0
    # fr * 2^-58 * pi/2 from its top 31 bits and a 31-bit pi/2.
    sh = ((f32bits(float(fr)) >> 23) - 127) - 30
    if sh >= 0:
        ft = fr >> sh
    else:
        ft = fr << -sh
    r = ft * 1686629713
    hi = float(r)
    lo = float(r - int(hi))
    sc = _P2[sh + 61]
    y0 = hi * sc
    y1 = lo * sc
    if neg:
        return n, -y0, -y1
    return n, y0, y1


def _rem_pio2(x):
    # ef_rem_pio2.c. Returns (n, y0, y1) with x = n*pi/2 + y0 + y1.
    hx = f32bits(x)
    ix = hx & 0x7FFFFFFF
    neg = hx & 0x80000000
    if ix < 0x4016cbe4:
        # |x| < 3pi/4: n = +-1.
        if not neg:
            z = x - 1.5707855224609375
            if (ix & 0xfffffff0) != 0x3fc90fd0:
                y0 = z - 1.0804334124259185e-05
                return 1, y0, (z - y0) - 1.0804334124259185e-05
            z -= 1.0804273e-05
            y0 = z - 6.07709993438732e-11
            return 1, y0, (z - y0) - 6.07709993438732e-11
        z = x + 1.5707855224609375
        if (ix & 0xfffffff0) != 0x3fc90fd0:
            y0 = z + 1.0804334124259185e-05
            return -1, y0, (z - y0) + 1.0804334124259185e-05
        z += 1.0804273e-05
        y0 = z + 6.07709993438732e-11
        return -1, y0, (z - y0) + 6.07709993438732e-11
    if ix <= 0x43490f80:
        # Medium size.
        t = abs(x)
        n = int(t * 0.6366198 + 0.5)
        fn = float(n)
        r = t - fn * 1.5707855224609375
        w = fn * 1.0804334124259185e-05
        y0 = r - w
        if n >= 32 or (ix & 0xffffff00) == _NPIO2_HW[n - 1]:
            j = ix >> 23
            i = j - ((f32bits(y0) >> 23) & 0xff)
            if i > 8:
                t = r
                w = fn * 1.0804273e-05
                r = t - w
                w = fn * 6.07709993438732e-11 - ((t - r) - w)
                y0 = r - w
                i = j - ((f32bits(y0) >> 23) & 0xff)
                if i > 25:
                    t = r
                    w = fn * 6.077094383272197e-11
                    r = t - w
                    w = fn * 6.123234e-17 - ((t - r) - w)
                    y0 = r - w
        y1 = (r - y0) - w
        if neg:
            return -n, -y0, -y1
        return n, y0, y1
    n, y0, y1 = _rem_big(abs(x))
    if neg:
        return -n, -y0, -y1
    return n, y0, y1


def sin(x):
    x = _f(x)
    ax = abs(x)
    if ax <= 0.785398006439209:
        return _ksin(x, 0.0, 0)
    if x != x:
        return x
    if ax == inf:
        _err()
    n, y0, y1 = _rem_pio2(x)
    n &= 3
    if n == 0:
        return _ksin(y0, y1, 1)
    if n == 1:
        return _kcos(y0, y1)
    if n == 2:
        return -_ksin(y0, y1, 1)
    return -_kcos(y0, y1)


def cos(x):
    x = _f(x)
    ax = abs(x)
    if ax <= 0.785398006439209:
        return _kcos(x, 0.0)
    if x != x:
        return x
    if ax == inf:
        _err()
    n, y0, y1 = _rem_pio2(x)
    n &= 3
    if n == 0:
        return _kcos(y0, y1)
    if n == 1:
        return -_ksin(y0, y1, 1)
    if n == 2:
        return -_kcos(y0, y1)
    return _ksin(y0, y1, 1)


def tan(x):
    x = _f(x)
    ax = abs(x)
    if ax <= 0.7853981256484985:
        return _ktan(x, 0.0, 1)
    if x != x:
        return x
    if ax == inf:
        _err()
    n, y0, y1 = _rem_pio2(x)
    return _ktan(y0, y1, 1 - ((n & 1) << 1))


# ---------------------------------------------------------------------------
# exp, log

def exp(x):
    x = _f(x)
    r = _exp(x)
    if r == inf and x != inf:
        _err()
    return r


def _exp(x):
    # musl expf (lib/libm/math.c).
    hx = f32bits(x)
    # f32bits is signed on the device; take the sign bit either way.
    sign = (hx >> 31) & 1
    hx &= 0x7FFFFFFF
    if hx >= 0x42aeac50:
        if hx >= 0x7f800000:
            # NaN, or +inf (exp(-inf) is 0 below).
            if hx > 0x7f800000 or not sign:
                return x
        if hx >= 0x42b17218 and not sign:
            return inf
        if sign and hx >= 0x42cff1b5:
            return 0.0
    if hx > 0x3eb17218:
        if hx > 0x3f851592:
            k = int(1.4426950216293335 * x + (-0.5 if sign else 0.5))
        else:
            k = 1 - sign - sign
        hi = x - k * 0.693145751953125
        lo = k * 1.428606765330187e-06
        x = hi - lo
    elif hx > 0x39000000:
        k = 0
        hi = x
        lo = 0.0
    else:
        return 1.0 + x
    xx = x * x
    c = x - xx * (0.16666625440120697 + xx * -0.0027667332906275988)
    y = 1.0 + (x * c / (2.0 - c) - lo + hi)
    if k == 0:
        return y
    return _scalbn(y, k)


def _log(x):
    # musl logf (lib/libm/math.c), for x > 0.
    ix = f32bits(x)
    k = 0
    if ix < 0x00800000:
        k = -25
        x = x * 33554432.0
        ix = f32bits(x)
    elif ix >= 0x7f800000:
        return x
    elif ix == 0x3f800000:
        return 0.0
    ix += 0x3f800000 - 0x3f3504f3
    k += (ix >> 23) - 0x7f
    ix = (ix & 0x007fffff) + 0x3f3504f3
    x = _fromb(ix)
    f = x - 1.0
    s = f / (2.0 + f)
    z = s * s
    w = z * z
    t1 = w * (0.40000972151756287 + w * 0.24279078841209412)
    t2 = z * (0.6666666269302368 + w * 0.2849878668785095)
    R = t2 + t1
    hfsq = 0.5 * f * f
    dk = float(k)
    return s * (hfsq + R) + dk * 9.05800061445916e-06 - hfsq + f + dk * 0.6931381225585938


def log(x, base=None):
    x = _f(x)
    if x <= 0.0:
        _err()
    l = _log(x)
    if base is None:
        return l
    base = _f(base)
    if base <= 0.0:
        _err()
    if base == 1.0:
        raise ZeroDivisionError('divide by zero')
    return l / _log(base)


def _log_hilo(x):
    # FreeBSD e_log2f.c / e_log10f.c reduction, for finite x > 0: returns
    # (k, hi, lo) with log(x) = k*ln2 + log(1+f), hi + lo = log1p(f) parts.
    hx = f32bits(x)
    k = 0
    if hx < 0x00800000:
        k = -25
        hx = f32bits(x * 33554432.0)
    k += (hx >> 23) - 127
    hx &= 0x007fffff
    i = (hx + 0x4afb0d) & 0x800000
    x = _fromb(hx | (i ^ 0x3f800000))
    k += i >> 23
    f = x - 1.0
    hfsq = 0.5 * f * f
    s = f / (2.0 + f)
    z = s * s
    w = z * z
    r = s * (hfsq + (z * (0.6666666269302368 + w * 0.2849878668785095) + w * (0.40000972151756287 + w * 0.24279078841209412)))
    hi = _fromb(f32bits(f - hfsq) & 0xfffff000)
    lo = (f - hi) - hfsq + r
    return float(k), hi, lo


def log2(x):
    x = _f(x)
    if x <= 0.0:
        _err()
    if x != x or x == inf:
        return x
    y, hi, lo = _log_hilo(x)
    return (lo + hi) * -0.00017605285393074155 + lo * 1.44287109375 + hi * 1.44287109375 + y


def log10(x):
    x = _f(x)
    if x <= 0.0:
        _err()
    if x != x or x == inf:
        return x
    y, hi, lo = _log_hilo(x)
    return y * 7.903415166765626e-07 + (lo + hi) * -3.168997136526741e-05 + lo * 0.434326171875 + hi * 0.434326171875 + y * 0.3010292053222656


def pow(x, y):
    x = _f(x)
    y = _f(y)
    if x < 0.0 and y == y and abs(y) != inf and float(int(y)) != y:
        _err()
    if x == 0.0 and y < 0.0:
        _err()
    r = x ** y
    if r == inf and abs(x) != inf and abs(y) != inf:
        _err()
    return r


# ---------------------------------------------------------------------------
# Exact helpers

def fabs(x):
    return abs(_f(x))


def copysign(x, y):
    x = abs(_f(x))
    y = _f(y)
    if y != y:
        return x
    if f32bits(y) & 0x80000000:
        return -x
    return x


def isnan(x):
    x = _f(x)
    return x != x


def isinf(x):
    return abs(_f(x)) == inf


def isfinite(x):
    x = _f(x)
    return x == x and abs(x) != inf


def trunc(x):
    return int(_f(x))


def floor(x):
    x = _f(x)
    i = int(x)
    if i > x:
        return i - 1
    return i


def ceil(x):
    x = _f(x)
    i = int(x)
    if i < x:
        return i + 1
    return i


def radians(x):
    return _f(x) * _DEG


def degrees(x):
    return _f(x) * _RAD


def ldexp(x, n):
    # MATH_FUN_2_FLT_INT: no domain check.
    x = _f(x)
    if not isinstance(n, int) and type(n) is not bool:
        _intarg(n)
    if x == 0.0 or x != x or abs(x) == inf:
        return x
    if n > 300:
        n = 300
    elif n < -300:
        n = -300
    return _scalbn(x, n)


def frexp(x):
    x = _f(x)
    if x == 0.0 or x != x or abs(x) == inf:
        return (x, 0)
    b = f32bits(x)
    ex = (b >> 23) & 255
    if ex == 0:
        x = x * 33554432.0
        b = f32bits(x)
        ex = ((b >> 23) & 255) - 25
    return (_fromb((b & 0x807FFFFF) | 0x3f000000), ex - 126)


def modf(x):
    x = _f(x)
    if abs(x) == inf:
        return (copysign(0.0, x), x)
    if x != x:
        return (x, x)
    i = float(int(x)) if abs(x) < 8388608.0 else x
    if f32bits(x) & 0x80000000:
        i = copysign(i, -1.0)
    return (copysign(x - i, x), i)


def isclose(a, b, rel_tol=1e-9, abs_tol=0):
    a = _f(a)
    b = _f(b)
    rel_tol = _f(rel_tol)
    abs_tol = _f(abs_tol)
    if a == b:
        return True
    d = abs(a - b)
    if d == inf:
        return False
    return d <= abs_tol or d <= abs(rel_tol * a) or d <= abs(rel_tol * b)


def factorial(x):
    n = int(x) if isinstance(x, int) or type(x) is bool else _intarg(x)
    if n < 0:
        raise ValueError('negative factorial')
    r = 1
    i = 2
    while i <= n:
        r *= i
        i += 1
    return r


def _intarg(x):
    raise TypeError("can't convert " + type(x).__name__ + " to int")
