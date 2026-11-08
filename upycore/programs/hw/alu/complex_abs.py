# abs() of a complex: sqrtf(re*re + im*im) in binary32 (py/objcomplex.c),
# across magnitudes, with overflow to inf and the inf/nan/zero parts.


def make(r, i):
    return complex(r, i)


inf = float('inf')
nan = float('nan')
for r, i in ((3.0, 4.0), (1e10, 0.0), (1e-10, 0.0), (1e5, 1e5), (0.001, 0.002),
             (123456.0, 0.5), (1e18, 1e18), (3e20, 4e20), (1e-20, 1e-20),
             (1e-25, 1e-25), (0.0, -0.0), (-0.0, 0.0), (-7.5, -2.25),
             (inf, 1.0), (1.0, -inf), (nan, 1.0), (2.0, nan)):
    print(abs(make(r, i)))
