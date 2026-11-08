# Binary32 float formatting and parsing (py/formatfloat.c, py/parsenum.c,
# APPROX). Powers of five are the binary32 values of 5**n, so decimal_exp
# matches the host model that was checked against the oracle's repr.
# The positive table runs through the last finite power (5**55). The
# negative table covers the decimal exponents a binary32 value can have,
# not only the ten powers that divide exactly.
from ._abi import *

_MM = const(429496728)
_POW5 = (
    1065353216, 1084227584, 1103626240, 1123680256, 1142702080, 1162039296,
    1182016512, 1201182336, 1220459552, 1240361768, 1259668217, 1278886839,
    1298715813, 1318159591, 1337320993, 1357078441, 1376656330, 1395761852,
    1415449451, 1435158307, 1454209260, 1473828647, 1493665400, 1512663062,
    1532215836, 1552177489, 1571123110, 1590610831, 1610694457, 1629589256,
    1649013450, 1669099388, 1688061358, 1707423513, 1727431903, 1746539276,
    1765840846, 1785773506, 1805022873, 1824265280, 1844123984, 1863512018,
    1882696646, 1902483128, 1922006579, 1941134784, 1960850735, 1980506430,
    1999579533, 2019226608, 2039011446, 2058030740, 2077610553, 2097521507,
    2116488252, 2136002379,
)
_POW5N = (
    1045220557, 1025758986, 1006834287, 986822423, 967296428, 948320189,
    928432021, 908840055, 889811039, 870049535, 850390015, 831306956,
    811675155, 791946460, 772808061, 753309077, 733509546, 714314479,
    694951498, 675079432, 655826336, 636602625, 616656282, 597343765,
    578262664, 558240262, 538866898, 519931830, 499831544, 480395872,
    461491891, 441430303, 421930828, 402975805, 383036718, 363471909,
    344464618, 324650973, 305019262, 285958449, 266273256, 246573037,
    227457418, 207903761, 188133389, 168961649, 149542683, 129700476,
    110471267, 91190226, 71274459, 51986403, 32846596, 12855504,
    2571101, 514220, 102844, 20569, 4114, 823,
)
_LOG10_2 = 0.3010299956639812


def _frombits(b):
    if b >= _U32 // 2:
        b = b - _U32
    return _mk(TAG_FLOAT, b)


def _pow5(n):
    if n >= 0:
        if n >= len(_POW5):
            return _frombits(2139095040)
        return _frombits(_POW5[n])
    if -n <= len(_POW5N):
        return _frombits(_POW5N[-n - 1])
    return 0.0


# decimal_exp multiplies by a power of five, in binary32, as the oracle does.
def _decimal_exp(num, e):
    if e == 0 or num == 0.0:
        return num
    b = _u32(_pay(num))
    exp = ((b >> 23) & 255) + e
    b = (b & ~(255 << 23)) | ((exp & 255) << 23)
    r = _frombits(b)
    if -10 <= e < 0:
        return r / _pow5(-e)
    return r * _pow5(e)


def _fkind(f):
    # 0 finite, 1 inf, 2 nan.
    b = _u32(_pay(f))
    if ((b >> 23) & 255) != 255:
        return 0
    if (b & 8388607) == 0:
        return 1
    return 2


def _ff_parse(s):
    # The check parser inside mp_format_float. s is the digits it just emitted.
    mant = 0
    exp_val = 0
    extra = 0
    tzi = 0
    tzf = 0
    st = 0
    neg = False
    eneg = False
    i = 0
    n = _slen(s)
    if n and _byte(s, 0) == 45:
        neg = True
        i = 1
    while i < n:
        c = _byte(s, i)
        i += 1
        if 48 <= c <= 57:
            d = c - 48
            if st == 2:
                exp_val = 10 * exp_val + d
            elif d == 0 or mant >= _MM:
                if st == 0:
                    tzi += 1
                else:
                    tzf += 1
            else:
                z = tzi
                w = 0
                while w < 2:
                    k = z if w == 0 else tzf
                    while k:
                        if mant < _MM:
                            if w == 1:
                                extra -= 1
                            mant = 10 * mant
                        elif w == 0:
                            extra += 1
                        k -= 1
                    w += 1
                tzi = 0
                tzf = 0
                if mant < _MM:
                    if st == 1:
                        extra -= 1
                    mant = 10 * mant + d
                elif st == 0:
                    extra += 1
        elif st == 0 and c == 46:
            st = 1
        elif st != 2 and (c == 101 or c == 69):
            st = 2
            if i < n and (_byte(s, i) == 43 or _byte(s, i) == 45):
                eneg = _byte(s, i) == 45
                i += 1
            else:
                eneg = False
        elif c == 95:
            continue
        else:
            break
    if st == 2 and eneg:
        exp_val = -exp_val
    exp_val += extra + tzi
    v = _decimal_exp(mant + 0.0, exp_val)
    if neg:
        return -v
    return v


def _fmt_mantissa(mant, cap, prefix, ndig, max_exp_zeros, trailing, dec, e, mode_g, mode_f, mode_e):
    if mant and mant >= cap:
        if mode_f:
            ndig += 1
            dec += 1
        else:
            mant //= 10
            e += 1
    s = prefix
    if mode_g and e != 0:
        if e >= 0:
            if e < max_exp_zeros:
                dec += e
                if dec >= ndig:
                    trailing = dec - (ndig - 1)
                e = 0
        elif e >= -4:
            cnt = 0
            while e < 0 and mant % 10 == 0:
                mant //= 10
                cnt += 1
                e += 1
            ndig -= cnt
            s = _cat(s, '0.')
            s = _cat(s, _mul_str('0', cnt - e - 1))
            dec = 255
            e = 0
    digs = ''
    m = mant
    i = 0
    while i < ndig:
        digs = _cat(_ch(48 + m % 10), digs)
        m //= 10
        i += 1
    dot = dec >= 255
    if dec + 1 < ndig:
        dot = True
        digs = _cat(_substr(digs, 0, dec + 1, TAG_STR), _cat('.', _substr(digs, dec + 1, ndig, TAG_STR)))
    s = _cat(s, digs)
    if trailing:
        dec -= ndig - 1
        while trailing:
            trailing -= 1
            if dec == 0:
                s = _cat(s, '.')
                dot = True
            dec -= 1
            s = _cat(s, '0')
    if mode_g and dot:
        while _slen(s) and _byte(s, _slen(s) - 1) == 48:
            s = _substr(s, 0, _slen(s) - 1, TAG_STR)
        if _slen(s) and _byte(s, _slen(s) - 1) == 46:
            s = _substr(s, 0, _slen(s) - 1, TAG_STR)
    if (e != 0 or mode_e) and not mode_f:
        s = _cat(s, 'e')
        if e >= 0:
            s = _cat(s, '+')
        else:
            s = _cat(s, '-')
            e = -e
        if e >= 100:
            s = _cat(s, _ch(48 + e // 100))
        s = _cat(s, _ch(48 + (e // 10) % 10))
        s = _cat(s, _ch(48 + e % 10))
    return s, e


def _format_float(f, fmt, prec, sign):
    buf_size = 33
    if _pay(f) < 0 and _fkind(f) != 2:
        f = -f
        sign = '-'
    if sign:
        buf_size -= 1
    kind = _fkind(f)
    if kind == 1:
        return _cat(sign, 'inf')
    if kind == 2:
        return _cat(sign, 'nan')
    mode_f = fmt == 'f'
    mode_g = fmt == 'g'
    mode_e = not mode_f and not mode_g
    if prec < 0:
        prec = 6
    max_exp_zeros = prec if prec < buf_size - 3 else buf_size - 3
    if prec == 99:
        prec = 9
        max_exp_zeros = 16
    e = 0
    if f != 0.0:
        expval = ((_u32(_pay(f)) >> 23) & 255) - 127
        e = _ftoi(expval * _LOG10_2)
        if e is STOP:
            e = 0
        pos = not (_u32(_pay(f)) < 1065353216)
        ub = _decimal_exp(1.0, e + (1 if pos else 0))
        while (f >= ub) == pos:
            e += 1 if pos else -1
            ub = _decimal_exp(1.0, e + (1 if pos else 0))
    if mode_f and e > 0 and e + prec + 2 > buf_size:
        mode_f = False
        mode_g = True
        prec += 1
    max_digits = prec
    lead_zeros = 0
    trail_zeros = 0
    if mode_f:
        if max_digits > buf_size - 3:
            max_digits = buf_size - 3
        if e < 0:
            if max_digits > 2 and e < -2:
                lead_zeros = (-e if -e < max_digits else max_digits) - 2
                max_digits -= lead_zeros
            else:
                max_digits += 1
        else:
            max_digits += e + 1
    elif not mode_g or max_digits == 0:
        max_digits += 1
    if max_digits > 9:
        trail_zeros = max_digits - 9
        max_digits = 9
    overhead = 3 if mode_f else 7
    if trail_zeros > buf_size - max_digits - overhead:
        trail_zeros = buf_size - max_digits - overhead
    ndig = 6 if 6 < max_digits else max_digits
    while True:
        prefix = ''
        extra_zeros = trail_zeros + (max_digits - ndig)
        dec = 0
        if f == 0.0:
            decexp = 0
        elif mode_f:
            decexp = ndig - 1
            if e < 0:
                if lead_zeros > 0:
                    prefix = _cat('0.', _mul_str('0', lead_zeros))
                    decexp += lead_zeros + 1
                    dec = 255
                else:
                    dec = 0
            else:
                decexp -= e
                dec = e
        else:
            decexp = ndig - e - 1
        cap = 10 ** ndig
        mant = 1
        if ndig > 6 and decexp > 1:
            if ndig > 7 and decexp > 2:
                mant = 100
                decexp -= 2
            else:
                mant = 10
                decexp -= 1
        mf = _decimal_exp(f, decexp)
        iv = _ftoi(mf + 0.5)
        if iv is STOP:
            iv = _ftoi(mf)
            if iv is STOP:
                iv = 0
        mant = (mant * iv) & (_U32 - 1)
        # e is the value's decimal exponent. _fmt_mantissa may fold it into
        # the digit string for 'g' and return that display exponent. The
        # next wider attempt still needs the original e.
        out, _shown = _fmt_mantissa(mant, cap, prefix, ndig, max_exp_zeros, extra_zeros, dec, e, mode_g, mode_f, mode_e)
        check = _ff_parse(out)
        diff = check - f
        best_diff = diff
        best = mant
        if diff == 0.0:
            return _cat(sign, out)
        err = 1
        if ndig > 6:
            err <<= 3 * (ndig - 6)
        runs = 12
        retry = False
        while runs > 0:
            runs -= 1
            if _pay(diff) < 0:
                mant += err
            else:
                mant -= err
            out, _shown = _fmt_mantissa(mant, cap, prefix, ndig, max_exp_zeros, extra_zeros, dec, e, mode_g, mode_f, mode_e)
            check = _ff_parse(out)
            diff = check - f
            if diff == 0.0:
                return _cat(sign, out)
            ad = diff if _pay(diff) >= 0 else -diff
            bd = best_diff if _pay(best_diff) >= 0 else -best_diff
            delta = ad - bd
            if _pay(delta) < 0 or (delta == 0.0 and mant % 10 == 0):
                best_diff = diff
                best = mant
            if err > 1:
                err >>= 1
            else:
                if ndig < max_digits:
                    ndig += 1
                    retry = True
                    break
                if mant != best:
                    out, _shown = _fmt_mantissa(best, cap, prefix, ndig, max_exp_zeros, extra_zeros, dec, e, mode_g, mode_f, mode_e)
                return _cat(sign, out)
        if not retry:
            return _cat(sign, out)


def _float_repr(f):
    s = _format_float(f, 'g', 99, '')
    n = _slen(s)
    i = 0
    dot = False
    exp = False
    nan = False
    while i < n:
        c = _byte(s, i)
        if c == 46:
            dot = True
        elif c == 101 or c == 69:
            exp = True
        elif c == 110:
            nan = True
        i += 1
    if not dot and not exp and not nan:
        return _cat(s, '.0')
    return s


def _complex_repr(c):
    re, im = _cparts(c)
    # Same rule as complex_print: -0.0 counts as a zero real, so -0j stays
    # "-0j" rather than "(-0-0j)". Precision 99 is MP_FLOAT_REPR_PREC.
    if re != 0.0:
        rr = _format_float(re, 'g', 99, '')
        ir = _format_float(im, 'g', 99, '+')
        return _s('(', rr, ir, 'j)')
    return _cat(_format_float(im, 'g', 99, ''), 'j')


def _skip_ws(s, i):
    n = _slen(s)
    while i < n and _byte(s, i) <= 32:
        i += 1
    return i


def _fold(c):
    if 65 <= c <= 90:
        return c + 32
    return c


def _has_prefix(s, word):
    n = _slen(word)
    if _slen(s) < n:
        return False
    i = 0
    while i < n:
        if _fold(_byte(s, i)) != _byte(word, i):
            return False
        i += 1
    return True


def _parse_float(s):
    n = _slen(s)
    i = _skip_ws(s, 0)
    if i >= n:
        raise ValueError('invalid syntax for number')
    neg = False
    if _byte(s, i) == 43 or _byte(s, i) == 45:
        neg = _byte(s, i) == 45
        i += 1
    rest = _substr(s, i, n, TAG_STR)
    # inf / nan, case-insensitive, then the digit parser. Trailing space is allowed.
    if _has_prefix(rest, 'inf'):
        j = 8 if _has_prefix(rest, 'infinity') else 3
        if _skip_ws(rest, j) != _slen(rest):
            raise ValueError('invalid syntax for number')
        return _frombits(4286578688 if neg else 2139095040)
    if _has_prefix(rest, 'nan'):
        if _skip_ws(rest, 3) != _slen(rest):
            raise ValueError('invalid syntax for number')
        return _frombits(4290772992 if neg else 2143289344)
    v = _ff_parse(_substr(s, i, n, TAG_STR))
    # _ff_parse stops at the first bad byte. Require one number and only
    # trailing space: a single dot, an exponent digit when e is present,
    # and underscores ignored the way parsenum.c ignores them.
    j = i
    saw = False
    exp = False
    exp_digit = False
    dot = False
    while j < n:
        c = _byte(s, j)
        if c == 95:
            j += 1
            continue
        if not exp and (c == 101 or c == 69):
            exp = True
            j += 1
            continue
        if c == 43 or c == 45:
            if exp and not exp_digit:
                p = j - 1
                while p >= i and _byte(s, p) == 95:
                    p -= 1
                if p >= i and (_byte(s, p) == 101 or _byte(s, p) == 69):
                    j += 1
                    continue
            break
        if 48 <= c <= 57:
            if exp:
                exp_digit = True
            else:
                saw = True
            j += 1
            continue
        if c == 46 and not exp and not dot:
            dot = True
            j += 1
            continue
        break
    if not saw or (exp and not exp_digit) or _skip_ws(s, j) != n:
        raise ValueError('invalid syntax for number')
    if neg:
        return -v
    return v


def float____new__(cls, *args):
    n = len(args)
    if n > 1:
        _arg_count(1, n)
    if n == 0:
        v = 0.0
    else:
        a = args[0]
        t = _tag(a)
        if t == TAG_FLOAT:
            v = a
        elif _isint(a):
            v = a + 0.0
        elif _isstr(a):
            v = _parse_float(a)
        elif t == TAG_OBJECT:
            f = _tlookup(_ld(a, 1), '__float__')
            if f is NULL:
                raise TypeError(_s("can't convert ", _tname(a), " to float"))
            v = _call_member(f, a, ())
        else:
            raise TypeError(_s("can't convert ", _tname(a), " to float"))
    if cls is not float:
        return _native_sub_new(cls, v)
    return v


def complex____new__(cls, *args):
    n = len(args)
    if n > 2:
        _arg_count(2, n)
    re = 0.0
    im = 0.0
    if n == 1 and _isstr(args[0]):
        return _parse_complex(args[0]) if cls is complex else _native_sub_new(cls, _parse_complex(args[0]))
    if n >= 1:
        a = args[0]
        if _tag(a) == TAG_COMPLEX:
            re, im = _cparts(a)
        else:
            re = float(a)
    if n == 2:
        b = args[1]
        if _tag(b) == TAG_COMPLEX:
            bre, bim = _cparts(b)
            re -= bim
            im += bre
        else:
            im += float(b)
    c = _complex(re, im)
    if cls is not complex:
        return _native_sub_new(cls, c)
    return c


def _parse_complex(s):
    n = _slen(s)
    i = _skip_ws(s, 0)
    j = n
    while j > i and _byte(s, j - 1) <= 32:
        j -= 1
    if j > i and (_byte(s, j - 1) == 106 or _byte(s, j - 1) == 74):
        j -= 1
        body = _substr(s, i, j, TAG_STR)
        # "j" is 1j. A sign alone is that sign on 1.
        blen = _slen(body)
        if blen == 0:
            return _complex(0.0, 1.0)
        if blen == 1 and (_byte(body, 0) == 43 or _byte(body, 0) == 45):
            return _complex(0.0, -1.0 if _byte(body, 0) == 45 else 1.0)
        # real+imag without the trailing j. Split at the last + or - that
        # isn't the leading sign and isn't the exponent sign.
        k = blen - 1
        split = -1
        while k > 0:
            c = _byte(body, k)
            if c == 43 or c == 45:
                p = _byte(body, k - 1)
                if p != 101 and p != 69:
                    split = k
                    break
            k -= 1
        if split < 0:
            return _complex(0.0, _parse_float(body))
        return _complex(_parse_float(_substr(body, 0, split, TAG_STR)), _parse_float(_substr(body, split, _slen(body), TAG_STR)))
    return _complex(_parse_float(_substr(s, i, j, TAG_STR)), 0.0)


# ---------------------------------------------------------------------------
# Binary32 libm kernels for complex ** (py/objcomplex.c calls sqrtf, logf,
# atan2f, expf, cosf, sinf). Ports of the pinned lib/libm routines, the ones
# bare-metal MicroPython ports use, in the C operation order; every +, -, *,
# / rounds to binary32 on the FPU exactly as the C does. The same kernels
# serve upycore/runtime/math.py, which cannot share these firmware-private
# names. Results are within 1 ulp of the unix oracle's glibc.

def _fsqrt(x):
    # The core sends float ** 0.5 to the FPU's correctly rounded square
    # root, so this is sqrtf bit for bit (inf, nan and +0 included).
    if x < 0.0:
        return _frombits(2143289344)
    return x ** 0.5


def _lm_p2(k):
    # 2.0 ** k for -149 <= k <= 127, exactly.
    if k >= -126:
        return _frombits((k + 127) << 23)
    return _frombits(1 << (k + 149))


def _lm_scalbn(y, n):
    # musl scalbnf.
    if n > 127:
        y = y * _lm_p2(127)
        n -= 127
        if n > 127:
            y = y * _lm_p2(127)
            n -= 127
            if n > 127:
                n = 127
    elif n < -126:
        y = y * _lm_p2(-102)
        n += 102
        if n < -126:
            y = y * _lm_p2(-102)
            n += 102
            if n < -126:
                n = -126
    return y * _lm_p2(n)


def _lm_ksin(x, y, iy):
    # kf_sin.c
    if -7.450581e-09 < x < 7.450581e-09:
        return x
    z = x * x
    v = z * x
    r = 0.008333333767950535 + z * (-0.00019841270113829523 + z * (2.7557314297155244e-06 + z * (-2.5050759688838298e-08 + z * 1.5896910177115586e-10)))
    if iy == 0:
        return x + v * (-0.1666666716337204 + z * r)
    return x - ((z * (0.5 * y - v * r) - y) - v * -0.1666666716337204)


def _lm_kcos(x, y):
    # kf_cos.c
    ax = -x if x < 0.0 else x
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


# 2/pi as 31-bit windows (ef_rem_pio2.c two_over_pi): _LM_W31[k - 1] holds
# bits k .. k+30, bit k weighing 2^-k.
_LM_W31 = (
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
_LM_NPIO2_HW = (
    0x3fc90f00, 0x40490f00, 0x4096cb00, 0x40c90f00, 0x40fb5300, 0x4116cb00,
    0x412fed00, 0x41490f00, 0x41623100, 0x417b5300, 0x418a3a00, 0x4196cb00,
    0x41a35c00, 0x41afed00, 0x41bc7e00, 0x41c90f00, 0x41d5a000, 0x41e23100,
    0x41eec200, 0x41fb5300, 0x4203f200, 0x420a3a00, 0x42108300, 0x4216cb00,
    0x421d1400, 0x42235c00, 0x4229a500, 0x422fed00, 0x42363600, 0x423c7e00,
    0x4242c700, 0x42490f00,
)


def _lm_bits(x):
    return _u32(_pay(x))


def _lm_tpbits(k0, n):
    if k0 >= 1:
        return _LM_W31[k0 - 1] >> (31 - n)
    return _LM_W31[0] >> (31 - n + 1 - k0)


def _lm_rem_big(ax):
    # |x| > 2^7*pi/2, reduced exactly with 64-bit limbs over 2/pi.
    b = _lm_bits(ax)
    ex = (b >> 23) - 150
    m = (b & 0x7FFFFF) | 0x800000
    k0 = ex - 2
    a = m * _lm_tpbits(k0 + 60, 31)
    q = ((m * _lm_tpbits(k0, 29)) & 0x1FFFFFFF) << 32
    q = (q + ((m * _lm_tpbits(k0 + 29, 31)) << 1) + (a >> 30)) & 0x1FFFFFFFFFFFFFFF
    n = (q + 0x200000000000000) >> 58
    fr = q - (n << 58)
    neg = fr < 0
    if neg:
        fr = -fr
    if fr == 0:
        return n, 0.0, 0.0
    sh = ((_lm_bits(float(fr)) >> 23) - 127) - 30
    if sh >= 0:
        ft = fr >> sh
    else:
        ft = fr << -sh
    r = ft * 1686629713
    hi = float(r)
    lo = float(r - int(hi))
    sc = _lm_p2(sh - 88)
    y0 = hi * sc
    y1 = lo * sc
    if neg:
        return n, -y0, -y1
    return n, y0, y1


def _lm_rem_pio2(x):
    # ef_rem_pio2.c: x = n*pi/2 + y0 + y1.
    hx = _lm_bits(x)
    ix = hx & 0x7FFFFFFF
    neg = hx & 0x80000000
    if ix < 0x4016cbe4:
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
        t = -x if neg else x
        n = int(t * 0.6366198 + 0.5)
        fn = float(n)
        r = t - fn * 1.5707855224609375
        w = fn * 1.0804334124259185e-05
        y0 = r - w
        if n >= 32 or (ix & 0xffffff00) == _LM_NPIO2_HW[n - 1]:
            j = ix >> 23
            i = j - ((_lm_bits(y0) >> 23) & 0xff)
            if i > 8:
                t = r
                w = fn * 1.0804273e-05
                r = t - w
                w = fn * 6.07709993438732e-11 - ((t - r) - w)
                y0 = r - w
                i = j - ((_lm_bits(y0) >> 23) & 0xff)
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
    n, y0, y1 = _lm_rem_big(-x if neg else x)
    if neg:
        return -n, -y0, -y1
    return n, y0, y1


def _lm_sincos(x, want_cos):
    # sf_sin.c / sf_cos.c without the domain error (complex ** gives nan).
    ax = -x if x < 0.0 else x
    if ax <= 0.785398006439209:
        return _lm_kcos(x, 0.0) if want_cos else _lm_ksin(x, 0.0, 0)
    if x != x or ax == _frombits(2139095040):
        return x - x
    n, y0, y1 = _lm_rem_pio2(x)
    n = (n + 1 if want_cos else n) & 3
    if n == 0:
        return _lm_ksin(y0, y1, 1)
    if n == 1:
        return _lm_kcos(y0, y1)
    if n == 2:
        return -_lm_ksin(y0, y1, 1)
    return -_lm_kcos(y0, y1)


def _lm_exp(x):
    # musl expf (lib/libm/math.c).
    hx = _lm_bits(x)
    sign = hx >> 31
    hx &= 0x7FFFFFFF
    if hx >= 0x42aeac50:
        if hx >= 0x7f800000:
            if hx > 0x7f800000 or not sign:
                return x
        if hx >= 0x42b17218 and not sign:
            return _frombits(2139095040)
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
    return _lm_scalbn(y, k)


def _lm_log(x):
    # musl logf (lib/libm/math.c), for x > 0 (and inf, nan).
    ix = _lm_bits(x)
    k = 0
    if ix < 0x00800000:
        k = -25
        x = x * 33554432.0
        ix = _lm_bits(x)
    elif ix >= 0x7f800000:
        return x
    elif ix == 0x3f800000:
        return 0.0
    ix += 0x3f800000 - 0x3f3504f3
    k += (ix >> 23) - 0x7f
    ix = (ix & 0x007fffff) + 0x3f3504f3
    x = _frombits(ix)
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


# atanf.c constants as their binary32 bit patterns, so no decimal parse is involved.
_LM_ATANHI = (0x3eed6338, 0x3f490fda, 0x3f7b985e, 0x3fc90fda)
_LM_ATANLO = (0x31ac3769, 0x33222168, 0x33140fb4, 0x33a22168)
_LM_AT = (0x3eaaaaa9, 0xbe4cca98, 0x3e11f50d, 0xbdda1247, 0x3d7cac25)


def _lm_atan(x):
    # atanf.c (musl).
    ix = _lm_bits(x)
    sign = ix >> 31
    ix &= 0x7fffffff
    if ix >= 0x4c800000:
        if x != x:
            return x
        z = _frombits(_LM_ATANHI[3]) + _lm_p2(-120)
        return -z if sign else z
    if ix < 0x3ee00000:
        if ix < 0x39800000:
            return x
        idx = -1
    else:
        x = -x if sign else x
        if ix < 0x3f980000:
            if ix < 0x3f300000:
                idx = 0
                x = (2.0 * x - 1.0) / (2.0 + x)
            else:
                idx = 1
                x = (x - 1.0) / (x + 1.0)
        elif ix < 0x401c0000:
            idx = 2
            x = (x - 1.5) / (1.0 + 1.5 * x)
        else:
            idx = 3
            x = -1.0 / x
    z = x * x
    w = z * z
    at = _LM_AT
    s1 = z * (_frombits(at[0]) + w * (_frombits(at[2]) + w * _frombits(at[4])))
    s2 = w * (_frombits(at[1]) + w * _frombits(at[3]))
    if idx < 0:
        return x - x * (s1 + s2)
    z = _frombits(_LM_ATANHI[idx]) - ((x * (s1 + s2) - _frombits(_LM_ATANLO[idx])) - x)
    return -z if sign else z


def _lm_atan2(y, x):
    # atan2f.c (musl).
    if x != x or y != y:
        return x + y
    ix = _lm_bits(x)
    iy = _lm_bits(y)
    if ix == 0x3f800000:
        return _lm_atan(y)
    m = ((iy >> 31) & 1) | ((ix >> 30) & 2)
    ix &= 0x7fffffff
    iy &= 0x7fffffff
    pi = _frombits(0x40490fdb)
    if iy == 0:
        if m <= 1:
            return y
        return pi if m == 2 else -pi
    if ix == 0:
        return -pi / 2.0 if m & 1 else pi / 2.0
    if ix == 0x7f800000:
        if iy == 0x7f800000:
            return (pi / 4.0, -pi / 4.0, 3.0 * pi / 4.0, -3.0 * pi / 4.0)[m]
        return (0.0, -0.0, pi, -pi)[m]
    if ix + (26 << 23) < iy or iy == 0x7f800000:
        return -pi / 2.0 if m & 1 else pi / 2.0
    if (m & 2) and iy + (26 << 23) < ix:
        z = 0.0
    else:
        q = y / x
        z = _lm_atan(-q if q < 0.0 else q)
    if m == 0:
        return z
    if m == 1:
        return -z
    if m == 2:
        return pi - (z - _frombits(0xb3bbbd2e))
    return (z - _frombits(0xb3bbbd2e)) - pi
