# Exercise byte-copy users: slice moves, growing storage, strings and bytes.
for start in range(4):
    for shift in range(1, 5):
        b = bytearray(range(64))
        expected = list(b)
        piece = expected[start:start + 27]
        expected[start + shift:start + shift + 27] = piece
        b[start + shift:start + shift + 27] = b[start:start + 27]
        assert list(b) == expected
        piece = expected[start + shift:start + shift + 27]
        expected[start:start + 27] = piece
        b[start:start + 27] = b[start + shift:start + shift + 27]
        assert list(b) == expected
b = bytearray(range(128))
for i in range(4):
    b.extend(bytes(range(64)))
assert list(b) == list(range(128)) + list(range(64)) * 4
for n in range(1, 17):
    s = ('abc' + str(n)) * n
    assert ''.join([s, 'x', s]) == s + 'x' + s
    assert bytes(bytearray(s, 'utf-8')) == s.encode()
print('byte moves ok', len(b))
