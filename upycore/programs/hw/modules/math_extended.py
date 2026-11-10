import math


def close(value, expected, rel=3e-5, absolute=1e-7):
    assert abs(value - expected) <= max(rel * abs(expected), absolute), (value, expected)


close(math.atan(1.0), 0.7853981633974483)
close(math.atan(-2.0), -1.1071487177940904)
close(math.atan2(2.0, -3.0), 2.5535900500422257)
close(math.atan2(-2.0, -3.0), -2.5535900500422257)
close(math.atan2(math.inf, -math.inf), 2.356194490192345)
assert math.copysign(1.0, math.atan(-0.0)) == -1.0
assert math.copysign(1.0, math.atan2(-0.0, 1.0)) == -1.0
close(math.atan2(-0.0, -0.0), -math.pi)
close(math.asin(-1.0), -math.pi / 2.0)
close(math.acos(-1.0), math.pi)
close(math.asin(0.99999994), 1.5704510598101804)
close(math.acos(0.99999994), 0.0003452669847162036)
close(math.acos(0.25), 1.318116071652818)
close(math.asinh(-5.0), -2.3124383412727525)
close(math.asinh(1e-8), 1e-8, absolute=1e-15)
close(math.acosh(1.00000012), 0.0004882812451493617)
close(math.acosh(9.0), 2.8872709503576206)
close(math.atanh(0.99999994), 8.664339742098155)
close(math.atanh(-0.25), -0.25541281188299536)
close(math.cosh(1.0), 1.5430806348152437)
close(math.sinh(-1.0), -1.1752011936438014)
close(math.tanh(0.5), 0.46211715726000974)
close(math.sinh(89.0), 2.2448064095871728e38)
assert math.tanh(-math.inf) == -1.0
assert math.sinh(-math.inf) == -math.inf
assert math.cosh(math.inf) == math.inf
close(math.expm1(-1e-8), -1e-8, absolute=1e-15)
close(math.expm1(0.5), 0.6487212707001282)
assert math.expm1(-math.inf) == -1.0

assert math.fmod(-7.5, 2.0) == -1.5
assert math.fmod(7.5, -2.0) == 1.5
assert math.fmod(1.0e30, 3.0) == 0.0
assert math.fmod(1.0, math.inf) == 1.0
assert math.copysign(1.0, math.fmod(-2.0, 1.0)) == -1.0
assert math.isnan(math.fmod(math.nan, 0.0))

close(math.erf(1.0), 0.8427007929497149)
close(math.erf(-2.0), -0.9953222650189527)
close(math.erfc(1.0), 0.15729920705028513)
close(math.erfc(1.25), 0.07709987174354177)
close(math.erfc(1.5), 0.033894853524689274)
close(math.erfc(8.0), 1.1224297172982928e-29, absolute=0.0)
assert math.erfc(-math.inf) == 2.0
assert math.erf(math.inf) == 1.0
assert math.isnan(math.erf(math.nan))
close(math.gamma(0.5), 1.7724538509055159)
close(math.gamma(-0.5), -3.544907701811032)
close(math.gamma(-1.5), 2.363271801207355)
close(math.gamma(6.0), 120.0)
close(math.gamma(30.25), 2.0628053137753476e31)
assert math.lgamma(1.0) == 0.0
assert math.lgamma(2.0) == 0.0
close(math.lgamma(-2.5), -0.05624371649767406)
close(math.lgamma(100.0), 359.1342053695754)
assert math.lgamma(-math.inf) == math.inf

for name, args in (
    ('acos', (2.0,)), ('asin', (math.inf,)), ('acosh', (0.5,)),
    ('atanh', (1.0,)), ('expm1', (100.0,)), ('cosh', (100.0,)),
    ('sinh', (-100.0,)), ('fmod', (1.0, 0.0)), ('fmod', (math.inf, 1.0)),
    ('gamma', (-2.0,)), ('gamma', (40.0,)), ('lgamma', (0.0,)),
):
    try:
        getattr(math, name)(*args)
    except ValueError:
        pass
    else:
        raise AssertionError(name)

print('atan2 %.6f erf %.6f gamma %.6f' % (math.atan2(1, 1), math.erf(1), math.gamma(0.5)))
