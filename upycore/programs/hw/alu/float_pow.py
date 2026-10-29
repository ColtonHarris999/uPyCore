def pw(a, b):
    return a ** b


def add(a, b):
    return a + b


def mul(a, b):
    return a * b


def div(a, b):
    return a / b


def lt(a, b):
    return a < b


def eq(a, b):
    return a == b


def trap(f, a, b):
    try:
        print(f(a, b))
    except Exception as e:
        print(type(e).__name__)


# Powers of two as the base: the log reduction leaves no digits to run.
print(pw(2.0, 0.5), pw(4.0, 0.5), pw(0.5, 3.5), pw(8.0, div(1, 3)))
# Fractional exponents, bases on both sides of 1.
print(pw(1.5, 2.3), pw(0.75, 3.7), pw(3.0, 0.1), pw(10.0, -3.5), pw(2.5, 20.5))
# Bases next to 1: the first log digit starts late.
print(pw(1.0001, 10000.0), pw(0.9999, -5000.0), pw(1.0000001, 0.5))
# Integral float exponents, negative bases.
print(pw(1.5, 3.0), pw(-2.0, 3.0), pw(-2.0, 2.0), pw(-0.5, -3.0))
# An int on either side, and int ** negative int (a float result).
print(pw(2, 0.5), pw(2.0, 3), pw(9, -0.5), pw(2, -2), pw(10, -1))
# Overflow and underflow.
print(pw(10.0, 50.0), pw(10.0, -50.0), pw(0.5, 200.0))
# Errors decided before the unit runs.
trap(pw, 0.0, -1.0)
trap(pw, 0, -1.5)
trap(div, 1.0, 0)
trap(div, 7, 0)
# Mixed int / float arithmetic and compares (the int is converted first).
print(div(7, 2), add(1, 0.5), mul(3, 0.25), lt(1, 1.5), lt(2.5, 2), eq(3, 3.0))
print(lt(2 ** 40, 1e13), eq(2 ** 24 + 1, 16777216.0), add(2 ** 40, 0.5))
# Subnormal binary32 operands.
x = 1e-40
print(x, add(x, x), mul(x, 2), div(x, 4), lt(0.0, x), pw(x, 0.5))
