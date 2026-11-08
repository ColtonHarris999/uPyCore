# float(), int() and type() of one argument (core natives) next to the
# forms the firmware still does.
inf = float('inf')
for v in [0, -0, 1, -7, 2 ** 30, -2 ** 30, 2 ** 31 - 1, 2 ** 40, True, False, 0.0, -0.0, 1.5, -2.75,
          1e10, -3e9, 2.5e9, 16777217, 123456789]:
    print(repr(float(v)), int(v) if not isinstance(v, float) or abs(v) < 1e30 else '-')
for v in [0.5, -0.5, 0.9999, -1.9999, 2147483647.0, 2147483648.0, -2147483648.0, 9.2e18]:
    print(int(v))
for bad in [inf, -inf, float('nan')]:
    try:
        print(int(bad))
    except (ValueError, OverflowError) as e:
        print(type(e).__name__, e)
print(float(), int(), float('1.25'), int('-42'), int('ff', 16), float(' 2e3 '))
class F(float):
    pass
class I(int):
    pass
print(F(2), type(F(2)) is F, I(3) + 1, type(I(3)) is I)
class Fl:
    def __float__(self):
        return 9.5
    def __int__(self):
        return 9
print(float(Fl()))
for v in [1, 1.0, 'a', b'a', [], (), {}, set(), None, True, range(2), 1j, Fl, type, len, 2 ** 40, Fl()]:
    print(type(v).__name__ if hasattr(type(v), '__name__') else type(v))
print(type('X', (), {'a': 1})().a)
for bad in ['x', None, [1]]:
    for f in (float, int):
        try:
            print(f(bad))
        except (ValueError, TypeError) as e:
            print(f.__name__, type(e).__name__)
try:
    float(1, 2)
except TypeError as e:
    print('TypeError')
