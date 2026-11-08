# Complex true division in py/objcomplex.c's order: a real or imaginary
# divisor takes its own branch; otherwise the divisor is scaled by its
# squared length and the quotient is a multiply.


def make(r, i):
    return complex(r, i)


pairs = (
    ((1.5, 2.5), (0.5, 1.0)),
    ((1.0, 1.0), (3.0, 7.0)),
    ((-2.5, 0.3), (0.7, -1.9)),
    ((1.0, 2.0), (0.0, 2.0)),
    ((1.0, 2.0), (4.0, 0.0)),
    ((3.0, -4.0), (1e-3, 2e3)),
    ((1e10, 1e-10), (3.0, 3.0)),
)
for a, b in pairs:
    print(make(*a) / make(*b))
print(make(2.0, 3.0) / 2, make(2.0, 3.0) / 0.5, 1 / make(0.0, 2.0), 2.5 / make(1.0, 1.0))
for d in (make(0.0, 0.0), 0, 0.0):
    try:
        make(1.0, 1.0) / d
    except ZeroDivisionError as e:
        print('ZeroDivisionError', e)
