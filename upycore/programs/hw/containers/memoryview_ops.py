# memoryview (py/objarray.c, format 'B'): views of bytes, bytearray and str,
# slicing into views, stores through a view, and the error order.
import gc
b = bytearray(b'abcdef')
m = memoryview(b)
print(type(m), len(m), m[0], m[-1], list(m[1:3]), bytes(m[2:]), len(m[4:2]), m)
s = m[1:5]
s[0] = 90
s[1] = 300
print(b, s[1], s[-1], len(s), list(s[1:][1:]))
print(m == b'ZZ', m[0:1] == b'a', memoryview(b'xy') == b'xy', memoryview(b'xy') == memoryview(b'xy'), b'ab' == memoryview(b'ab'))
print(memoryview(b'ab')[0], len(memoryview('héllo')), memoryview('ab')[1], isinstance(m, memoryview))


def load(f):
    try:
        print(f())
    except Exception as e:
        print(type(e).__name__, e)


load(lambda: m[10])
load(lambda: m['a'])
load(lambda: m[::2])
load(lambda: memoryview(5))
load(lambda: memoryview())
load(lambda: memoryview(b'a', b'b'))
load(lambda: m[2 ** 40])
load(lambda: hash(m))
load(lambda: m + b'x')


def store(f):
    try:
        f()
        print('ok', b)
    except Exception as e:
        print(type(e).__name__, e)


def setitem(t, i, v):
    t[i] = v


def delitem(t, i):
    del t[i]


def setslice(t, v):
    t[0:2] = v


def setstep(t, v):
    t[::2] = v


ro = memoryview(b'ab')
store(lambda: setitem(ro, 0, 1))
store(lambda: setitem(m, 0, 'x'))
store(lambda: delitem(m, 0))
store(lambda: setslice(m, b'QQ'))
store(lambda: setslice(m, b'Q'))
store(lambda: setslice(m, [1, 2]))
store(lambda: setslice(m, bytearray(b'RR')))
store(lambda: setslice(m, memoryview(b'ST')))
store(lambda: setstep(m, b'ab'))
store(lambda: setslice(ro, b'xy'))
m2 = memoryview(m)
print(len(m2), m2[0], [x for x in memoryview(b'\x01\x02')], bytearray(memoryview(b'q')), bytes(memoryview(bytearray(b'r'))))
ba = bytearray(4)
ba[:] = memoryview(b'wxyz')
print(ba)
# The misc_mandel pattern: rows of one buffer through slice views.
img = bytearray(12)
for v in range(3):
    line = memoryview(img)[v * 4:v * 4 + 4]
    for u in range(4):
        line[u] = v * 4 + u
print(img)
# A view keeps its buffer alive on its own.
view = memoryview(bytearray(b'kept'))[1:]
gc.collect()
junk = [bytearray(32) for i in range(50)]
gc.collect()
print(bytes(view))
