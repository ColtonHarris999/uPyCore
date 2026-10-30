# Requests at and beyond the collector's block-count wrap must fail cleanly.
for n in (524288, 524289, 1048576, 2097152, 1073741823):
    try:
        b = bytes(n)
    except MemoryError:
        print('MemoryError')
    else:
        raise AssertionError('oversized bytes allocation succeeded')
try:
    a = [None] * 131073
except MemoryError:
    print('MemoryError')
else:
    raise AssertionError('oversized list allocation succeeded')
print(bytes(0), [1, 2, 3])
