from array import array

assert repr(array('b')) == "array('b')"

for code, low, high in (
    ('b', -128, 127), ('B', 0, 255), ('h', -32768, 32767),
    ('H', 0, 65535), ('i', -2147483648, 2147483647), ('I', 0, 4294967295),
    ('l', -2147483648, 2147483647), ('L', 0, 4294967295),
    ('q', -9223372036854775807 - 1, 9223372036854775807),
    ('Q', 0, 9223372036854775807), ('f', -1.5, 2.25), ('d', -1.5, 2.25),
):
    a = array(code, [low, high])
    assert list(a) == [low, high], (code, a)
    assert list(array(code, bytes(a))) == [low, high], code
    assert list(a[-1:]) == [high]
    v = memoryview(a)
    assert len(v) == 2
    assert v[0] == low and v[-1] == high, (code, list(v))
    v[-1] = low
    assert a[-1] == low, code
    s = v[1:]
    s[0] = high
    assert a[-1] == high and bytes(s) == bytes(a[-1:]), code
    a[1:] = array(code, [low, high])
    a.extend(a)
    assert list(a) == [low, low, high, low, low, high], code

a = array('H', b'\x34\x12\x78\x56\x01')
assert list(a) == [0x1234, 0x5678]
assert list(a + b'\x00\x01') == [0x1234, 0x5678, 256]
a += b'\x00\x01'
assert a == array('H', [0x1234, 0x5678, 256])
assert bytes(bytearray(a)) == b'\x34\x12\x78\x56\x00\x01'
s = memoryview(a)
s[0:2] = array('H', [11, 22])
assert list(a) == [11, 22, 256]
a[1:2] = array('H', [33])
assert s[1] == 33
s[1] = 22
try:
    s[:1] = b'xx'
except ValueError:
    pass
else:
    raise AssertionError('width mismatch')
try:
    array('f', ['1'])
except TypeError:
    pass
else:
    raise AssertionError('float array accepted a string')
f = array('f', b'\x01\x00\x00\x00')
assert 0.0 < f[0] < 1e-44
d = array('d', b'\x00\x00\x00\x00\x00\x00\xf8\x3f')
assert d[0] == 1.5
assert bytes(d) == b'\x00\x00\x00\x00\x00\x00\xf8\x3f'
print(list(a), list(d))
