# Requests at and beyond the collector's block-count wrap must fail cleanly.
for n in (262144, 262145, 524288, 1048576, 1073741823):
    try:
        b = bytes(n)
    except MemoryError:
        print('MemoryError')
    else:
        raise AssertionError('oversized bytes allocation succeeded')
try:
    a = [None] * 65537
except MemoryError:
    print('MemoryError')
else:
    raise AssertionError('oversized list allocation succeeded')
print(bytes(0), [1, 2, 3])
