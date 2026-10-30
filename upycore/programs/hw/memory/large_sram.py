# A single payload of 256 KiB exercises the widened logical and physical
# word indices. bytearray(n) currently needs a second temporary buffer, so
# use bytes to test addressing without that extra peak allocation.
b = bytes(262144)
points = (0, 65535, 65536, 131071, 131072, 196607, 196608, 262143)
print(len(b), [b[p] for p in points])
print(b[1], b[65537], b[131073], b[196609])
