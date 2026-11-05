# Scalar bytearray and bytes indexing. The core reads and writes an exact
# bytearray directly for small-int and bool indices; everything else takes
# the firmware hook. Both paths must agree with the oracle.


def show(tag, f):
    try:
        print(tag, f())
    except Exception as e:
        print(tag, type(e).__name__, e)


# Every byte lane of several words, read and written, with neighbours checked.
b = bytearray(range(11))
print([b[i] for i in range(11)])
print([b[-i] for i in range(1, 12)])
for i in range(11):
    b[i] = 200 + i
print(list(b))
for i in range(11):
    b[i] = i * 17
    print(i, list(b))

# Zero- and one-byte buffers.
z = bytearray()
show('z0', lambda: z[0])
show('z-1', lambda: z[-1])
o = bytearray(b'\xff')
print(o[0], o[-1])
show('o1', lambda: o[1])
show('o-2', lambda: o[-2])
o[0] = 7
o[-1] += 1
print(list(o))

# Out-of-range stores do not touch the buffer.
c = bytearray(b'abcd')


def setit(buf, i, v):
    buf[i] = v
    return list(buf)


show('s4', lambda: setit(c, 4, 1))
show('s-5', lambda: setit(c, -5, 1))
show('s-4', lambda: setit(c, -4, 1))
print(list(c))

# Bool indices and values.
d = bytearray(b'\x01\x02\x03')
print(d[True], d[False])
d[True] = True
d[False] = False
print(list(d))

# Values outside 0..255 keep the low byte.
e = bytearray(4)
for v in (255, 256, 257, -1, -128, -256, -257, 1000, 0x7fffffff, -0x40000000):
    e[1] = v
    print(v, list(e))

# Wide and custom indices, and wrong value types.
show('wide', lambda: e[2 ** 40])
show('wide-', lambda: e[-(2 ** 40)])
show('swide', lambda: setit(e, 2 ** 40, 1))
show('wval', lambda: setit(e, 0, 2 ** 40))


class Idx:
    def __index__(self):
        return 2


show('idx', lambda: e[Idx()])
show('sidx', lambda: setit(e, Idx(), 9))
show('fidx', lambda: e[1.0])
show('sidx-f', lambda: setit(e, 1.0, 1))
show('fval', lambda: setit(e, 0, 1.5))
show('sval', lambda: setit(e, 0, 'a'))
show('nval', lambda: setit(e, 0, None))
show('bval', lambda: setit(e, 0, b'a'))
print(list(e))


def delit(buf, i):
    del buf[i]


show('del', lambda: delit(e, 0))
print(list(e))


# Subclasses keep their own item methods.
class BA(bytearray):
    pass


class LoudBA(bytearray):
    def __getitem__(self, i):
        return ('get', i)

    def __setitem__(self, i, v):
        print('set', i, v)


s = BA(b'xyz')
print(s[0], s[-1])
s[1] = 65
print(bytes(s))
show('sub-oob', lambda: s[3])
L = LoudBA(b'pq')
print(L[0], L[-1])
L[0] = 1

# Immutable bytes: high-bit bytes index by byte.
hb = b'\x00\x7f\x80\xff\xfe'
print([hb[i] for i in range(len(hb))], hb[-1], hb[-5])
show('hb5', lambda: hb[5])
show('hb-6', lambda: hb[-6])
sbox = bytes((i * 7 + 3) & 255 for i in range(256))
print(sum(sbox[i] for i in range(256)), sbox[255], sbox[-256])

# Reads and writes right after a bulk copy builds or extends the buffer.
big = bytes(range(256)) * 2
f = bytearray(big)
print(f[0], f[255], f[256], f[511], f[-1])
f[300] = 1
f[301] = 2
print(f[299], f[300], f[301], f[302])
f.extend(big)
print(len(f), f[1023], f[512], f[300])
f[1023] = 9
print(f[1022], f[1023])
g = f[:]
g[0] = 99
print(f[0], g[0], g[1], g[1023])
f[2:6] = b'WXYZ'
print(f[1], f[2], f[5], f[6])

# A checksum loop of the kind AES runs.
st = bytearray(range(16))
for r in range(8):
    for i in range(16):
        st[i] = sbox[st[i] ^ st[(i + 1) & 15]]
print(list(st))

# Error order and value conversion on the hook path.
class IntOnly:
    def __int__(self):
        return 260


show('del-oob', lambda: delit(e, 9))
show('oob-f', lambda: setit(e, 9, 1.5))
show('str-f', lambda: setit(e, 'a', 1.5))
show('int-val', lambda: setit(e, 0, IntOnly()))
show('wneg', lambda: setit(e, 0, -2 ** 40 - 1))
show('swide', lambda: 'abc'[2 ** 40])
show('sflt', lambda: 'abc'[1.5])
show('bflt', lambda: b'abc'[1.5])
show('bidx', lambda: b'abc'[Idx()])
