# Check both ASCII table lookups and Unicode/binary fallback boundaries.
for code in (0, 65, 127, 128, 255, 0x20ac, 0x10000, 0x10ffff):
    print(code, ord(chr(code)))
print(ord(chr(True)), ord(b'\xff'), ord(bytearray(b'\x80')))
print(ord(''.join(['x', 'a'])[1:]))
for value in (-1, 0x110000, 1.5, None):
    try:
        chr(value)
    except Exception as e:
        print(type(e).__name__)
for value in ('', 'ab', b'', b'ab', 3):
    try:
        ord(value)
    except Exception as e:
        print(type(e).__name__)
