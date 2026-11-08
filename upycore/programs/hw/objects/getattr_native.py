# getattr / setattr with interned and built names on instances, classes,
# modules, properties, methods, __getattr__ and __setattr__.
class A:
    k = 5

    def m(self):
        return 'm'

    @property
    def p(self):
        return 'prop'


class G:
    def __getattr__(self, name):
        return 'dyn:' + name


a = A()
setattr(a, 'x', 1)
print(getattr(a, 'x'), getattr(a, 'x', 9), getattr(a, 'y', 9))
setattr(a, 'x', getattr(a, 'x') + 1)
print(a.x, getattr(a, 'k'), getattr(A, 'k'), getattr(a, 'p'))
print(getattr(a, 'm')(), getattr(A, 'm')(a))
print(getattr(a, '__class__') is A, getattr(a, '__dict__'))
name = ''.join(['x', 'y', 'z'])
setattr(a, name, 3)
print(getattr(a, name), getattr(a, 'xyz'), a.xyz)
try:
    getattr(a, 'missing')
except AttributeError as e:
    print('AttributeError', e)
try:
    getattr(a, 1)
except TypeError as e:
    print('TypeError', e)
try:
    setattr(a, 1, 2)
except TypeError as e:
    print('TypeError')
g = G()
print(getattr(g, 'q'), getattr(g, 'q', 0))
setattr(A, 'k', 7)
print(A.k, a.k, getattr(a, 'k'))
print(getattr(1, 'real', 0), getattr('s', 'nope', 'dflt'))
e = ValueError('v')
print(getattr(e, 'args'))
for w in ['a', 'b', 'a', 'c', 'b', 'a']:
    setattr(a, w, getattr(a, w, 0) + 1)
print(a.a, a.b, a.c)
