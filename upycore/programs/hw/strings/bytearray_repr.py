# bytearray repr keeps the b prefix, as bytes does.
b = bytearray(b'ab')
print(b, repr(b), str(b), [b])
b[0] = 90
print(b, bytearray(), bytearray(3), bytearray([1, 2, 200]), bytearray(b"it's"), bytearray(b'q"\'\n\x00'))
