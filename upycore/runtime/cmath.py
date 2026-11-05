# cmath for uPyCore: binary32, frozen, linked only into programs that import
# it. Built on the frozen math module; the formulas follow py/modcmath.c.
#
# Not implemented yet: phase, polar, log, log10, sqrt, cos, sin (they need
# atan2, which math does not have yet).

import math

e = math.e
pi = math.pi


def _c(z):
    # mp_obj_get_complex: complex, or anything math accepts as a float.
    if type(z) is complex:
        return z.real, z.imag
    if isinstance(z, complex):
        return z.real, z.imag
    return math._f(z), 0.0


def rect(r, phi):
    r = math._f(r)
    phi = math._f(phi)
    return complex(r * math.cos(phi), r * math.sin(phi))


def exp(z):
    re, im = _c(z)
    ex = math._exp(re)
    return complex(ex * math.cos(im), ex * math.sin(im))
