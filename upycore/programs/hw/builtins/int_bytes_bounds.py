print((258).to_bytes(2), int.from_bytes(b'\x01\x02'))
print((1).to_bytes(), int.from_bytes(b'\x01\x02', 'little'))
for n, width in ((-1, 1), (-128, 1), (127, 1), (-32768, 2),
                 (-9223372036854775807 - 1, 8), (9223372036854775807, 8)):
    print(n.to_bytes(width, 'big', signed=True))
    print(n.to_bytes(width, 'little', signed=True))
print((-1).to_bytes(10, signed=True), (0).to_bytes(0))
print(int.from_bytes(b'\xff\xff\xff\xff\xff\xff\xff\xff'))
print(int.from_bytes(b'\x80\x00\x00\x00\x00\x00\x00\x00'))
for n, width, signed in ((-1, 1, False), (128, 1, True), (-129, 1, True),
                         (256, 1, False), (1, 0, False), (-1, 0, True)):
    try:
        n.to_bytes(width, signed=signed)
    except OverflowError:
        print('OverflowError')
    else:
        raise AssertionError('out of range integer accepted')
