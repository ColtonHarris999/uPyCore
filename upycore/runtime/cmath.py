# cmath for uPyCore: binary32, frozen, linked only into programs that import
# it. Built on the frozen math module; the formulas follow py/modcmath.c.

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
    if abs(phi) == math.inf:
        return complex._from_parts(math.nan, math.nan)
    return complex._from_parts(r * math.cos(phi), r * math.sin(phi))


def exp(z):
    re, im = _c(z)
    if abs(im) == math.inf:
        return complex._from_parts(math.nan, math.nan)
    ex = math._exp(re)
    return complex._from_parts(ex * math.cos(im), ex * math.sin(im))


def phase(z):
    re, im = _c(z)
    return math._atan2(im, re)


def polar(z):
    re, im = _c(z)
    return math.sqrt(re * re + im * im), math._atan2(im, re)


def log(z):
    re, im = _c(z)
    mag2 = re * re + im * im
    logmag = -math.inf if mag2 == 0.0 else 0.5 * math.log(mag2)
    return complex._from_parts(logmag, math._atan2(im, re))


def log10(z):
    re, im = _c(z)
    mag2 = re * re + im * im
    logmag = -math.inf if mag2 == 0.0 else 0.5 * math.log10(mag2)
    return complex._from_parts(logmag, 0.4342944819032518 * math._atan2(im, re))


def sqrt(z):
    re, im = _c(z)
    root = (re * re + im * im) ** 0.25
    theta = 0.5 * math._atan2(im, re)
    return complex._from_parts(root * math.cos(theta), root * math.sin(theta))


def cos(z):
    re, im = _c(z)
    if abs(re) == math.inf:
        return complex._from_parts(math.nan, math.nan)
    return complex._from_parts(math.cos(re) * math._cosh(im), -math.sin(re) * math._sinh(im))


def sin(z):
    re, im = _c(z)
    if abs(re) == math.inf:
        return complex._from_parts(math.nan, math.nan)
    return complex._from_parts(math.sin(re) * math._cosh(im), math.cos(re) * math._sinh(im))
