# math (frozen runtime module): exact functions bit for bit, the libm ports
# printed at 6 significant digits (they may differ from the host libm in the
# last bit), the error rules of py/modmath.c, and math.pi folded by mpy-cross.
import math
from math import sin, cos, sqrt

print(math.pi, math.e, math.tau, math.inf, -math.inf, math.nan)
for v in (0.0, -0.0, 1e-45, 1e-40, 2.0, 2, True, 0.5, 3.0, 1e30, 3.4e38, 12345.678, math.inf):
    print('sqrt', v, sqrt(v))
for x in (0.0, 0.5, 1.0, -1.0, 2.0, 3.1415927, 7.0, 100.0, 202, 249, 1e4, 1e6, 3e7, 1e10, 1e20, -1e20, 3.4e38):
    print('trig', x, '%.6g %.6g %.6g' % (sin(x), cos(x), math.tan(x)))
for x in (1e-10, 0.5, 1.0, 2.0, 2.718281828, 10.0, 1e10, 3.4e38, 1e-40, 8, 1024):
    print('log', x, '%.6g %.6g %.6g' % (math.log(x), math.log2(x), math.log10(x)), '%.6g' % math.log(x, 3))
for x in (-104.0, -87.0, -1.0, -1e-5, 0.0, 1e-5, 0.3, 1.0, 10.0, 88.0, -math.inf):
    print('exp', x, '%.6g' % math.exp(x))
for x in (2.5, -2.5, 2.0, -0.5, 1e10, -7, 0.999999):
    print('round', x, math.floor(x), math.ceil(x), math.trunc(x), math.modf(x), math.frexp(x))
print(math.ldexp(0.75, 3), math.ldexp(1.0, -149), math.ldexp(1.0, 200), math.copysign(3, -0.0), math.copysign(-2.0, 1))
print(math.fabs(-3), math.isnan(math.nan), math.isinf(-math.inf), math.isfinite(1.0), math.isfinite(math.nan))
print('%.6g %.6g' % (math.radians(180), math.degrees(math.pi)), math.factorial(0), math.factorial(10))
print(math.isclose(1.0, 1.0 + 1e-10), math.isclose(1.0, 1.1), math.isclose(0.0, 1e-10, abs_tol=1e-9))
print('%.6g %.6g' % (math.pow(2, 10), math.pow(2.0, 0.5)), math.pow(-8.0, 3.0))


for name, a in (('sqrt', (-1.0,)), ('log', (0.0,)), ('log', (-2,)), ('log', (2, 1)), ('log', (2, -1)),
                ('exp', (100.0,)), ('sin', (math.inf,)), ('cos', (math.nan,)), ('sin', ('x',)),
                ('sqrt', (1j,)), ('floor', (math.inf,)), ('factorial', (-1,)), ('factorial', (2.5,)),
                ('pow', (-8.0, 0.5)), ('pow', (0.0, -1.0)), ('log2', (0,)), ('log10', (-1,))):
    try:
        print(name, a, getattr(math, name)(*a))
    except Exception as e:
        print(name, a, type(e).__name__, e)
