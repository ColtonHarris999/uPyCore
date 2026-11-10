import cmath
import math


def close(z, re, im):
    assert abs(z.real - re) <= 2e-6 * max(1.0, abs(re)), z
    assert abs(z.imag - im) <= 2e-6 * max(1.0, abs(im)), z


assert cmath.phase(complex(-1.0, 0.0)) == math.pi
assert abs(cmath.phase(complex('-1-0j')) + math.pi) <= 3e-7
r, theta = cmath.polar(3 + 4j)
assert r == 5.0
assert abs(theta - 0.9272952180016122) <= 2e-7
close(cmath.log(3 + 4j), 1.6094379124341003, 0.9272952180016122)
close(cmath.log10(3 + 4j), 0.6989700043360189, 0.4027191962733731)
assert cmath.log(0).real == -math.inf
assert cmath.log10(0).real == -math.inf
close(cmath.sqrt(3 + 4j), 2.0, 1.0)
close(cmath.sqrt(complex('-4-0j')), 0.0, -2.0)
close(cmath.sin(1 + 2j), 3.165778513216168, 1.9596010414216063)
close(cmath.cos(1 + 2j), 2.0327230070196656, -3.0518977991518)
assert math.isnan(cmath.sin(complex(math.inf, 1)).real)
assert math.isnan(cmath.exp(complex(0, math.inf)).imag)
assert math.isnan(cmath.rect(1, math.inf).real)
assert math.isnan(cmath.log(complex(float('-nan'), 1)).real)
assert math.copysign(1.0, cmath.rect(1, -0.0).imag) == -1.0
print('polar %.6f %.6f' % (r, theta))
