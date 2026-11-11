# Optional wide integers. Each box uses the ordinary OBJECT tag and int type.
# After the header, packed little-endian 30-bit limbs occupy one SRAM word
# each. Their INT tags keep the limb words out of the GC pointer graph.
_WIDE_BASE = const(1073741824)
_WIDE_MASK = const(1073741823)
_WIDE_MAX_LIMBS = const(GC_POOL_BYTES // 4 - 3)


def _iswide(x):
    return _tag(x) == TAG_OBJECT and _ld(x, 0) == OB_BIGINT


def _wide_size(x, n):
    while n and _pay(_ld(x, n + 2)) == 0:
        n -= 1
    return n


def _wide_finish(x, n, neg):
    n = _wide_size(x, n)
    if not n:
        return 0
    if n < 3 or (n == 3 and _pay(_ld(x, 5)) < 8):
        v = 0
        for i in range(n - 1, -1, -1):
            v = (v << 30) | _pay(_ld(x, i + 3))
        return -v if neg else v
    if neg and n == 3 and _pay(_ld(x, 5)) == 8 and _pay(_ld(x, 4)) == 0 and _pay(_ld(x, 3)) == 0:
        return -9223372036854775807 - 1
    _st(x, 2, -n if neg else n)
    return x


def _wide_box(x):
    if _iswide(x):
        return x
    b = _limb_new(3)
    neg = x < 0
    # Complement first so the magnitude of INT64_MIN never enters the ALU.
    v = -(x + 1) if neg else (1 if x is True else 0 if x is False else x)
    carry = 1 if neg else 0
    n = 0
    while v or carry:
        limb = (v & _WIDE_MASK) + carry
        _st(b, n + 3, limb & _WIDE_MASK)
        v >>= 30
        carry = limb >> 30
        n += 1
    _st(b, 2, -n if neg else n)
    return b


def _wide_cmp(a, an, b, bn):
    if an != bn:
        return -1 if an < bn else 1
    while an:
        av = _pay(_ld(a, an + 2))
        bv = _pay(_ld(b, an + 2))
        if av != bv:
            return -1 if av < bv else 1
        an -= 1
    return 0


def _wide_add_mag(a, an, b, bn):
    n = an if an > bn else bn
    out = _limb_new(n + 1)
    carry = _limb_mac(out, a, an, b, bn, 1)
    _st(out, n + 3, carry)
    return out, n + 1


def _wide_sub_into(out, a, an, b, bn):
    # |a| >= |b|. out may alias either input.
    _limb_mac(out, b, bn, a, an, -1)


def _wide_add(a, ac, b, bc):
    an, bn = abs(ac), abs(bc)
    if (ac < 0) == (bc < 0):
        out, n = _wide_add_mag(a, an, b, bn)
        return _wide_finish(out, n, ac < 0)
    if _wide_cmp(a, an, b, bn) < 0:
        a, b, an, bn, ac = b, a, bn, an, bc
    out = _limb_new(an)
    _wide_sub_into(out, a, an, b, bn)
    return _wide_finish(out, an, ac < 0)


def _wide_mul(a, ac, b, bc):
    an, bn = abs(ac), abs(bc)
    if not an or not bn:
        return 0
    if an < bn:
        a, b, an, bn = b, a, bn, an
    out = _limb_new(an + bn)
    for j in range(bn):
        digit = _pay(_ld(b, j + 3))
        if digit:
            row = _pay(out) + 4 * j
            carry = _limb_mac(row, a, an, row, an if j else 0, digit)
            _st(out, an + j + 3, carry)
    return _wide_finish(out, an + bn, (ac < 0) != (bc < 0))


def _wide_mul_small(a, b):
    if b == 0:
        return 0
    if b == 1:
        return a
    if b == -1:
        return _wide_unary(UNOP_NEGATIVE, a)
    ac = _ld(a, 2)
    n = abs(ac)
    out = _limb_new(n + 1)
    _st(out, n + 3, _limb_mac(out, a, n, 0, 0, abs(b)))
    return _wide_finish(out, n + 1, (ac < 0) != (b < 0))


def _wide_bits(a, n):
    if not n:
        return 0
    bits = (n - 1) * 30
    v = _pay(_ld(a, n + 2))
    while v:
        v >>= 1
        bits += 1
    return bits


def _wide_lshift(a, n, shift):
    words, bits = shift // 30, shift % 30
    out = _limb_new(n + words + 1)
    carry = 0
    for i in range(n):
        v = (_pay(_ld(a, i + 3)) << bits) | carry
        _st(out, i + words + 3, v & _WIDE_MASK)
        carry = v >> 30
    _st(out, n + words + 3, carry)
    return out, n + words + (1 if carry else 0)


def _wide_inc(a, n):
    # The caller reserves one extra word.
    i = 0
    while i < n and _pay(_ld(a, i + 3)) == _WIDE_MASK:
        _st(a, i + 3, 0)
        i += 1
    _st(a, i + 3, _pay(_ld(a, i + 3)) + 1 if i < n else 1)
    return max(n, i + 1)


def _wide_rshift(a, ac, shift):
    n = abs(ac)
    words, bits = shift // 30, shift % 30
    if words >= n:
        return -1 if ac < 0 else 0
    out = _limb_new(n - words + 1)
    carry = 0
    mask = (1 << bits) - 1
    for i in range(n - 1, words - 1, -1):
        v = _pay(_ld(a, i + 3))
        _st(out, i - words + 3, (v >> bits) | carry)
        carry = (v & mask) << (30 - bits)
    used = n - words
    if ac < 0:
        dropped = carry != 0
        for i in range(words):
            if _pay(_ld(a, i + 3)):
                dropped = True
                break
        if dropped:
            used = _wide_inc(out, used)
    return _wide_finish(out, used, ac < 0)


def _wide_short_quotient(a, an, b, bn):
    # Let H be the retained high limbs and M the discarded power of the
    # radix. The actual difference A - q*B lies between
    # (Ha - q*Hb - q)*M (inclusive) and (Ha - q*Hb + 1)*M (exclusive).
    # A nonnegative lower bound certifies floor(A/B) from the prefixes.
    if an < bn:
        return 0
    if bn < 2 or an > bn + 1:
        return -1
    ah = (_pay(_ld(a, bn + 2)) << 30) | _pay(_ld(a, bn + 1))
    if an > bn:
        top = _ld(a, an + 2)
        if top > 7:
            return -1
        ah |= top << 60
    bh = (_ld(b, bn + 2) << 30) | _pay(_ld(b, bn + 1))
    q = ah // bh
    return q if ah - q * bh >= q else -1


def _wide_div_mag(a, an, b, bn):
    if an < bn:
        rem = _limb_new(an)
        _wcopy(rem, 3, a, 3, an)
        return _limb_new(1), 0, rem, an
    if bn == 1:
        q = _limb_new(an + 1)
        rem = _limb_new(1)
        divisor = _ld(b, 3)
        carry = 0
        for i in range(an - 1, -1, -1):
            v = (carry << 30) | _pay(_ld(a, i + 3))
            digit = v // divisor
            _st(q, i + 3, digit)
            carry = v - digit * divisor
        _st(rem, 3, carry)
        return q, an, rem, 1 if carry else 0

    # Normalize the top divisor digit to >= radix/2. The top two
    # dividend digits then estimate each quotient digit within two.
    shift = bn * 30 - _wide_bits(b, bn)
    rem, _ = _wide_lshift(a, an, shift)
    if shift:
        b, _ = _wide_lshift(b, bn, shift)
    qn = an - bn + 1
    q = _limb_new(qn + 1)
    top = _ld(b, bn + 2)
    second = _pay(_ld(b, bn + 1))
    for j in range(qn - 1, -1, -1):
        high = _pay(_ld(rem, j + bn + 3))
        leading = (high << 30) | _pay(_ld(rem, j + bn + 2))
        digit = leading // top
        if digit > _WIDE_MASK:
            digit = _WIDE_MASK
        residual = leading - digit * top
        next_digit = _pay(_ld(rem, j + bn + 1))
        while residual < _WIDE_BASE and digit * second > (residual << 30) + next_digit:
            digit -= 1
            residual += top
        if digit:
            row = _pay(rem) + 4 * j
            high += _limb_mac(row, b, bn, row, bn, -digit)
            if high < 0:
                digit -= 1
                high += _limb_mac(row, b, bn, row, bn, 1)
            _st(rem, j + bn + 3, high)
        _st(q, j + 3, digit)
    if shift:
        carry = 0
        for i in range(bn + 2, 2, -1):
            v = _pay(_ld(rem, i))
            _st(rem, i, (v >> shift) | carry)
            carry = (v & ((1 << shift) - 1)) << (30 - shift)
    return q, qn, rem, _wide_size(rem, bn)


def _wide_divmod(a, ac, b, bc):
    an, bn = abs(ac), abs(bc)
    if not bn:
        raise ZeroDivisionError('divide by zero')
    q, qn, rem, rn = _wide_div_mag(a, an, b, bn)
    neg = (ac < 0) != (bc < 0)
    if neg and rn:
        qn = _wide_size(q, qn)
        qn = _wide_inc(q, qn)
        out = _limb_new(bn)
        _wide_sub_into(out, b, bn, rem, rn)
        rem, rn = out, bn
    return _wide_finish(q, qn, neg), _wide_finish(rem, rn, bc < 0)


def _wide_unary(op, a):
    if op == UNOP_POSITIVE:
        return a
    if op == UNOP_NOT:
        return False
    if op == UNOP_INVERT:
        return _wide_binary(BINOP_SUBTRACT, _wide_unary(UNOP_NEGATIVE, a), 1)
    ac = _ld(a, 2)
    if op == UNOP_ABS and ac > 0:
        return a
    n = abs(ac)
    out = _limb_new(n)
    _wcopy(out, 3, a, 3, n)
    return _wide_finish(out, n, op == UNOP_NEGATIVE and ac > 0)


def _wide_binary(op, a, b):
    if BINOP_INPLACE_OR <= op < BINOP_OR:
        op += BINOP_OR - BINOP_INPLACE_OR
    if not (_isint(a) or _iswide(a)) or not (_isint(b) or _iswide(b)):
        ta, tb = _tag(a), _tag(b)
        if op == BINOP_MULTIPLY and _iswide(a) and (_isstr(b) or tb == TAG_BYTES or tb == TAG_TUPLE or _islist(b)):
            return _wide_i32(a)
        numeric = ta == TAG_FLOAT or ta == TAG_COMPLEX or tb == TAG_FLOAT or tb == TAG_COMPLEX
        if numeric and (op <= BINOP_NOT_EQUAL or BINOP_ADD <= op <= BINOP_POWER and op != BINOP_MAT_MULTIPLY):
            if (ta == TAG_COMPLEX or tb == TAG_COMPLEX) and op <= BINOP_NOT_EQUAL and op != BINOP_EQUAL:
                return NULL
            return _apply(op, _wide_float(a) if ta == TAG_INT64 or _iswide(a) else a,
                          _wide_float(b) if tb == TAG_INT64 or _iswide(b) else b)
        return NULL
    if op == BINOP_LSHIFT or op == BINOP_RSHIFT:
        b = _wide_i32(b)
        if b < 0:
            raise ValueError('negative shift count')
        if not a:
            return 0
        if b > _WIDE_MAX_LIMBS * 30:
            if op == BINOP_RSHIFT:
                return -1 if a < 0 else 0
            raise MemoryError()
        a = _wide_box(a)
        ac = _ld(a, 2)
        if op == BINOP_RSHIFT:
            return _wide_rshift(a, ac, b)
        out, n = _wide_lshift(a, abs(ac), b)
        return _wide_finish(out, n, ac < 0)
    if op == BINOP_POWER:
        if b < 0:
            return float(a) ** float(b)
        return _wide_pow(a, b, None)
    if op == BINOP_TRUE_DIVIDE:
        if not b:
            raise ZeroDivisionError('divide by zero')
        return float(a) / float(b)
    if op == BINOP_MULTIPLY:
        if _tag(a) == TAG_INT and -_WIDE_MASK <= a <= _WIDE_MASK and _iswide(b):
            return _wide_mul_small(b, a)
        if _tag(b) == TAG_INT and -_WIDE_MASK <= b <= _WIDE_MASK and _iswide(a):
            return _wide_mul_small(a, b)
    if op == BINOP_ADD:
        if _tag(a) == TAG_INT and a == 0:
            return b
        if _tag(b) == TAG_INT and b == 0:
            return a
    if op == BINOP_FLOOR_DIVIDE and _iswide(a) and _iswide(b):
        ac, bc = _ld(a, 2), _ld(b, 2)
        if (ac < 0) == (bc < 0):
            q = _wide_short_quotient(a, abs(ac), b, abs(bc))
            if q >= 0:
                return q
    a, b = _wide_box(a), _wide_box(b)
    ac, bc = _ld(a, 2), _ld(b, 2)
    if op <= BINOP_NOT_EQUAL:
        if (ac < 0) != (bc < 0):
            cmp = -1 if ac < 0 else 1
        else:
            cmp = _wide_cmp(a, abs(ac), b, abs(bc))
            if ac < 0:
                cmp = -cmp
        if op == BINOP_EQUAL:
            return cmp == 0
        if op == BINOP_NOT_EQUAL:
            return cmp != 0
        if op == BINOP_LESS:
            return cmp < 0
        if op == BINOP_MORE:
            return cmp > 0
        if op == BINOP_LESS_EQUAL:
            return cmp <= 0
        return cmp >= 0
    if op == BINOP_ADD or op == BINOP_SUBTRACT:
        return _wide_add(a, ac, b, -bc if op == BINOP_SUBTRACT else bc)
    if op == BINOP_MULTIPLY:
        return _wide_mul(a, ac, b, bc)
    if op == BINOP_FLOOR_DIVIDE or op == BINOP_MODULO:
        q, r = _wide_divmod(a, ac, b, bc)
        return q if op == BINOP_FLOOR_DIVIDE else r
    if BINOP_OR <= op <= BINOP_AND:
        return _wide_bitwise(op, a, ac, b, bc)
    return NULL


def _int_overflow(op, a, b):
    if b is NULL:
        if op == UNOP_NEGATIVE:
            return _wide_unary(op, _wide_box(a))
    else:
        result = _wide_binary(op, a, b)
        if result is not NULL:
            return result
    raise OverflowError('result overflows long long storage')


def _wide_hash(a):
    # The existing int/int64 hash exposes the signed low 31 bits.
    v = _pay(_ld(a, 3)) | ((_pay(_ld(a, 4)) & 1) << 30)
    return _sx31(-v if _ld(a, 2) < 0 else v)


def _wide_repr(a):
    ac = _ld(a, 2)
    n = abs(ac)
    copy = _limb_new(n)
    _wcopy(copy, 3, a, 3, n)
    chunks = []
    while n:
        rem = 0
        for i in range(n + 2, 2, -1):
            v = (rem << 30) | _pay(_ld(copy, i))
            q = v // 1000000000
            _st(copy, i, q)
            rem = v - q * 1000000000
        n = _wide_size(copy, n)
        chunks.append(_istr(rem))
    out = [('-' if ac < 0 else '') + chunks.pop()]
    while chunks:
        chunk = chunks.pop()
        out.append('0' * (9 - len(chunk)) + chunk)
    return ''.join(out)



def _wide_i32(n):
    if not (_isint(n) or _iswide(n)):
        raise TypeError('integer required')
    if not -2147483648 <= n <= 2147483647:
        raise OverflowError('overflow converting long int to machine word')
    return n


def _wide_bitwise(op, a, ac, b, bc):
    # Convert one limb at a time to two's complement with infinite sign
    # extension. The extra limb records the sign of the result.
    an, bn = abs(ac), abs(bc)
    n = (an if an > bn else bn) + 1
    out = _limb_new(n)
    ca, cb = 1, 1
    for i in range(n):
        av = _pay(_ld(a, i + 3)) if i < an else 0
        bv = _pay(_ld(b, i + 3)) if i < bn else 0
        if ac < 0:
            av = (_WIDE_MASK ^ av) + ca
            ca, av = av >> 30, av & _WIDE_MASK
        if bc < 0:
            bv = (_WIDE_MASK ^ bv) + cb
            cb, bv = bv >> 30, bv & _WIDE_MASK
        if op == BINOP_OR:
            v = av | bv
        elif op == BINOP_XOR:
            v = av ^ bv
        else:
            v = av & bv
        _st(out, i + 3, v)
    neg = v != 0
    if neg:
        carry = 1
        for i in range(n):
            v = (_WIDE_MASK ^ _ld(out, i + 3)) + carry
            _st(out, i + 3, v & _WIDE_MASK)
            carry = v >> 30
    return _wide_finish(out, n, neg)


def _wide_pow(a, b, mod):
    result = 1
    if mod is not None:
        if not mod:
            raise ValueError('divide by zero')
        if b < 0 or mod == 1 or mod == -1:
            return 0
        result %= mod
        if not b:
            return result
        a %= mod
    while b:
        if b & 1:
            result *= a
            if mod is not None:
                result %= mod
        b >>= 1
        if b:
            a *= a
            if mod is not None:
                a %= mod
    return result


def _wide_chunk(a, n, bit, width):
    i, shift = bit // 30, bit % 30
    if i >= n:
        return 0
    v = _pay(_ld(a, i + 3)) >> shift
    if shift + width > 30 and i + 1 < n:
        v |= _pay(_ld(a, i + 4)) << (30 - shift)
    return v & ((1 << width) - 1)


def _wide_float(a):
    a = _wide_box(a)
    ac = _ld(a, 2)
    n = abs(ac)
    # The 32-bit MicroPython MPZ port accumulates 16-bit digits in binary32.
    bit = ((_wide_bits(a, n) - 1) // 16) * 16
    v = 0.0
    while bit >= 0:
        v = v * 65536.0 + _wide_chunk(a, n, bit, 16)
        bit -= 16
    return -v if ac < 0 else v


def _wide_from_float(x):
    raw = _pay(x)
    exponent = ((raw >> 23) & 255) - 150
    significand = (raw & 8388607) | 8388608
    return (-significand if raw < 0 else significand) << exponent


def _wide_from_bytes(b, little):
    length = _slen(b)
    out = _limb_new((length * 8 + 29) // 30)
    used, bits, pending = 0, 0, 0
    for i in range(length):
        pending |= _byte(b, i if little else length - 1 - i) << bits
        bits += 8
        if bits >= 30:
            _st(out, used + 3, pending & _WIDE_MASK)
            used += 1
            pending >>= 30
            bits -= 30
    if bits:
        _st(out, used + 3, pending)
        used += 1
    return _wide_finish(out, used, False)


def _wide_to_bytes(a, length, little, signed):
    a = _wide_box(a)
    ac = _ld(a, 2)
    n = abs(ac)
    if ac < 0 and not signed:
        raise OverflowError("can't convert negative int to unsigned")
    bits = _wide_bits(a, n)
    # The MPZ converter emits all bytes of each 16-bit digit. Check the
    # discarded bytes and the sign of its final byte, just as it does.
    used = ((bits + 15) // 16) * 2
    if bits > length * 8 and ac >= 0:
        raise OverflowError(_s('value would overflow a ', _istr(length), ' byte buffer'))
    out = _strnew(length, TAG_BYTES)
    data = _data(out)
    carry = 1
    fill = 255 if ac < 0 else 0
    last = 0
    for i in range(max(length, used)):
        byte = _wide_chunk(a, n, i * 8, 8)
        if ac < 0:
            byte = (255 ^ byte) + carry
            carry, byte = byte >> 8, byte & 255
        if i < length:
            _poke8(data, i if little else length - 1 - i, byte)
        elif byte != fill:
            raise OverflowError(_s('value would overflow a ', _istr(length), ' byte buffer'))
        last = byte
    if used >= length and signed and ((last ^ fill) & 128):
        raise OverflowError(_s('value would overflow a ', _istr(length), ' byte buffer'))
    return _strfin(out)


def _wide_base(a, base, prefix, upper):
    if base == 10:
        return _wide_repr(a)
    width = 1 if base == 2 else (3 if base == 8 else 4)
    ac = _ld(a, 2)
    n = abs(ac)
    count = (_wide_bits(a, n) + width - 1) // width
    out = _newstr(count)
    data = _data(out)
    for i in range(count):
        c = _byte(_HEX, _wide_chunk(a, n, i * width, width))
        _poke8(data, count - 1 - i, c - 32 if upper and c >= 97 else c)
    return _s('-' if ac < 0 else '', prefix, _fin(out, count))


def _wide_fmt_parts(a, conv, alternate, sign, group):
    base = 2 if conv == 'b' else 8 if conv == 'o' else 16 if conv == 'x' or conv == 'X' else 10
    prefix = ''
    if alternate and base != 10:
        prefix = '0' + conv
    digits = _istr(a) if base == 10 else _int_base(a, base, '', conv == 'X')
    if digits[0] == '-':
        sign, digits = '-', digits[1:]
    if group:
        step = 3 if base == 10 else 4
        first = len(digits) % step or step
        groups = [digits[:first]]
        for i in range(first, len(digits), step):
            groups.append(digits[i:i + step])
        digits = group.join(groups)
    return sign + prefix, digits


def _wide_pad(lead, digits, width, align, fill):
    pad = max(0, width - len(lead) - len(digits))
    if align == '=':
        return lead + fill * pad + digits
    text = lead + digits
    if align == '<':
        return text + fill * pad
    if align == '^':
        return fill * (pad // 2) + text + fill * (pad - pad // 2)
    return fill * pad + text


def _wide_format(a, spec):
    i, n = 0, len(spec)
    if not n:
        return _istr(a)
    align, fill, sign, group = '', ' ', '', ''
    if n > 1 and spec[1] in '<>=^':
        fill, align, i = spec[0], spec[1], 2
    elif n and spec[0] in '<>=^':
        align, i = spec[0], 1
    if i < n and spec[i] in '+- ':
        if spec[i] != '-':
            sign = spec[i]
        i += 1
    alternate = i < n and spec[i] == '#'
    if alternate:
        i += 1
    if i < n and spec[i] == '0':
        if not align:
            align, fill = '=', '0'
        i += 1
    width = 0
    while i < n and '0' <= spec[i] <= '9':
        width = width * 10 + ord(spec[i]) - 48
        i += 1
    if i < n and spec[i] in ',_':
        group = spec[i]
        i += 1
    precision = 6
    if i < n and spec[i] == '.':
        i += 1
        precision = 0
        while i < n and '0' <= spec[i] <= '9':
            precision = precision * 10 + ord(spec[i]) - 48
            i += 1
    if i + 1 < n:
        raise ValueError('invalid format specifier')
    conv = spec[i] if i < n else 'd'
    if conv == 'c':
        return _wide_pad('', chr(_wide_i32(a)), width, align, fill)
    if conv in 'eEfFgG%':
        number = float(a)
        mode = conv.lower()
        if conv == '%':
            number *= 100.0
            mode = 'f'
        text = _format_float(number, mode, precision, sign)
        if conv == '%':
            text += '%'
        elif 'A' <= conv <= 'Z':
            text = text.upper()
        lead = text[0] if text[0] in '+- ' else ''
        return _wide_pad(lead, text[len(lead):], width, align, fill)
    if conv == 's':
        raise ValueError(_s("unknown format code '", conv, "' for object of type 'int'"))
    if conv not in 'dboxXn':
        raise ValueError('invalid format specifier')
    lead, digits = _wide_fmt_parts(a, conv, alternate, sign, group)
    return _wide_pad(lead, digits, width, align, fill)
