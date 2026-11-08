# Complex ** and a negative float to a fractional power (a complex result).
# The device uses the binary32 lib/libm kernels; the oracle uses its host
# libm, which can differ in the last bit, so results print to 5 digits.


def make(r, i):
    return complex(r, i)


def show(z):
    print('%.5g %.5g' % (z.real, z.imag))


z = make(1.0, 2.0)
for w in (2, 2.0, 0.5, -1, 3, 10, make(0.5, 1.5), make(1.0, -1.0)):
    show(z ** w)
show(make(2.0, 0.0) ** 2)
show(make(0.0, 1.0) ** 2)
show(make(3.0, -4.0) ** make(1.0, 1.0))
show(make(100.0, -300.0) ** 0.3)
show(make(-1.0, 0.0) ** 0.5)
one = make(1.0, 0.0).real
for b in (-8.0, -2.0, -0.5):
    show(b ** (one / 3.0))
    show(b ** 0.5)
print(make(0.0, 0.0) ** 0, make(0.0, 0.0) ** 2, make(5.0, 1.0) ** 0)
for w in (-1, make(0.0, 1.0), make(-2.0, 0.0)):
    try:
        make(0.0, 0.0) ** w
    except ZeroDivisionError as e:
        print('ZeroDivisionError', e)
