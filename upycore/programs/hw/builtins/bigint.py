import gc


one = 1
two = 2
limit = 9223372036854775807
minimum = -limit - one
wide = one << 64
assert wide == 1 << 64 == 18446744073709551616
assert -wide == -18446744073709551616
assert type(wide) is int and isinstance(wide, int)
assert int(wide) is wide and int('0x10000000000000000', 16) == wide
assert int('-9223372036854775808') == minimum
assert int('-18446744073709551616') == -wide
assert limit + one == -minimum == minimum // -one
assert minimum % -one == 0
assert -limit // 3 == -3074457345618258603 and -limit % 3 == 2
assert minimum - one == -9223372036854775809
assert two ** 64 == wide and (one << 32) * (one << 32) == wide
assert wide - (wide - limit) == limit
assert abs(-wide) == wide and ~wide == -wide - one
assert (-wide - one) >> 64 == -two
assert str(wide) == '18446744073709551616'

for a in (wide + 101, -wide - 101):
    for b in (3, -3, wide // 7 + 5, -(wide // 7 + 5), wide * 3, -wide * 3):
        q, r = a // b, a % b
        assert q * b + r == a
        assert 0 <= r < b if b > 0 else b < r <= 0
        assert divmod(a, b) == (q, r)

a = (1 << 137) + 12345
b = (1 << 96) + 65
assert (a + b) - b == a
assert (-a + b) + a == b
assert (b - a) + a == b
assert a + -a == 0 and a - a == 0
assert a * -7 == -7 * a == -(a * 7)
assert a * 0 == 0 and 0 * a == 0 and a + 0 == 0 + a == a
near = (1 << 120) + 11
below = near - 1
assert below // near == 0 and near // below == 1
assert -near // below == -2 and near // -below == -2
assert near // (one << 117) == 8
assert divmod(b, a) == (0, b)
assert b % a == b
for x in (a, -a):
    for y in (b, -b):
        q, r = divmod(x, y)
        assert q * y + r == x
        assert 0 <= r < y if y > 0 else y < r <= 0
        assert (x & y) + (x | y) == x + y
        assert (x ^ y) == (x | y) - (x & y)
        assert (x ^ y) ^ y == x
        assert ((x & y) & 1) == ((x & 1) & (y & 1))

assert pow(3, wide + 5, 729) == 0
assert pow(wide, -1, 17) == 0
assert pow(wide, 0, -17) == -16
assert pow(2, wide, 17) == 1
assert pow(a, b, (1 << 131) - 1) == 829116990532198488414414541121193801187
assert float(wide) == wide and wide / (wide >> 4) == 16.0
assert int(float(wide) * 65536.0) == wide << 16
assert int(-float(wide)) == -wide
assert wide ** -1 == 1.0 / float(wide)
assert (wide + 2j) == complex(wide, 2) == (2j + wide)
assert float(wide) in {wide: 1} and wide in {float(wide): 1}
halfway = (one << 62) + (one << 38) + one
rounded = float(one << 62)
assert float(halfway) == rounded and halfway == rounded and rounded == halfway
assert halfway + 0.0 == rounded and halfway / one == rounded
assert halfway + 2j == complex(rounded, 2)

raw = b'\x81\x01\x02\x03\x04\x05\x06\x07\x08\x09'
value = int.from_bytes(raw)
assert value == 0x81010203040506070809
assert value.to_bytes(10) == raw
assert int.from_bytes(memoryview(raw), 'little').to_bytes(10, 'little') == raw
assert (-wide).to_bytes(10, 'big', signed=True) == b'\xff\xff' + b'\x00' * 8
assert hex(-wide) == '-0x10000000000000000'
assert bin(wide) == '0b1' + '0' * 64
assert oct(wide) == '0o2' + '0' * 21
assert '{:+#024x}'.format(wide) == '+0x000010000000000000000'
assert '{:,d}'.format(wide) == '18,446,744,073,709,551,616'
assert '%#024x' % -wide == '-0x000010000000000000000'
assert '%#X' % (wide - wide) == '0X0'
assert '%*d' % (22, wide) == '  18446744073709551616'
assert round(wide + 19, -1) == wide + 24
assert hash(wide + 7) == 7


def raises(expected, fn):
    try:
        fn()
    except expected:
        return
    raise AssertionError('missing exception')


raises(OverflowError, lambda: wide << wide)
raises(OverflowError, lambda: 0 << (one << 40))
raises(OverflowError, lambda: one >> (one << 40))
raises(OverflowError, lambda: one << -(one << 40))
raises(OverflowError, lambda: [0][wide])
raises(OverflowError, lambda: [0][:wide])
raises(OverflowError, lambda: range(wide))
raises(OverflowError, lambda: 'x' * wide)
raises(OverflowError, lambda: wide * 'x')
raises(OverflowError, lambda: chr(wide))
raises(OverflowError, lambda: bytearray(wide))
raises(OverflowError, lambda: wide.to_bytes(8))
raises(ZeroDivisionError, lambda: wide / 0)
raises(ValueError, lambda: pow(wide, 3, 0))
raises(ValueError, lambda: int('010', 0))
raises(ValueError, lambda: int('18446744073709551616\x01'))
raises(TypeError, lambda: int.from_bytes([1, 2]))

keys = {wide: 'wide', 0: 'zero', -wide: 'negative'}
gc.collect()
assert keys[18446744073709551616] == 'wide'
assert keys[-18446744073709551616] == 'negative'
assert keys[0] == 'zero'
assert wide in {wide, 0}
print('bigint ok')
