# repr of a bytearray keeps the b prefix of its bytes literal.
x = bytearray(b'upy')
print(x)
print(x[1:])
print(repr(bytearray()))
print([bytearray(b"it's")])
