# ord() / chr() natives, str/bytes slices by byte copy, and dict.get.
for c in ['a', '\x00', '\x7f', 'é', '€', b'a', b'\xff', 'Z']:
    print(ord(c))
for bad in ['', 'ab', b'', b'ab', bytearray(b'z'), 1, None]:
    try:
        print(ord(bad))
    except TypeError as e:
        print('TypeError', e)
print([chr(i) for i in (0, 9, 10, 65, 97, 126, 127, 128, 233, 8364, 128512)])
print(chr(True), repr(chr(False)))
for bad in (-1, 1114112, 2 ** 40, 'a', 1.0):
    try:
        print(chr(bad))
    except (ValueError, TypeError, OverflowError) as e:
        print(type(e).__name__)
s = 'The Zen of Python, by Tim Peters'
u = 'héllo wörld €uro'
b = b'bytes and more bytes'
ba = bytearray(b'a bytearray')
for i in range(0, 34, 3):
    print(repr(s[i:i * 2]), repr(u[i // 2:i]), b[i:i + 3], ba[i // 3:i])
print(repr(s[5:5]), repr(s[-3:]), repr(s[:-30]), s[::1] == s, repr(s[100:]))
d = {'a': 1, 2: 'two', (1, 2): 'tup', None: 0, 1.5: 'f'}
for k in ['a', 'b', 2, 3, (1, 2), (2, 1), None, 1.5, 2.0, True]:
    print(d.get(k), d.get(k, 'dflt'))
class D(dict):
    pass
dd = D(x=1)
print(dd.get('x'), dd.get('y', 5))
try:
    d.get([1])
except TypeError as e:
    print('TypeError', e)
counts = {}
for w in s.split(' ') * 3:
    counts[w] = counts.get(w, 0) + 1
print(sorted(counts.items()))
