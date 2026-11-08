# round() as mp_builtin_round: an int comes back exactly (integer rounding
# for negative ndigits), a float rounds half to even to an int, and a float
# with ndigits stays a float.


def g(x):
    return x


def show(f):
    try:
        print(repr(f()))
    except Exception as e:
        print(type(e).__name__, e)


for v in (16777217, 2 ** 40 + 1, -7, True, 2.7, -2.7, 2.5, 3.5, -0.5, -0.3,
          0.49999997, 8388607.5, 1e9, 1e20, float('inf'), float('nan')):
    show(lambda: round(g(v)))
for v, n in ((7, 2), (12345, -2), (12350, -2), (12450, -2), (-12350, -2),
             (2 ** 40 + 50, -2), (2.675, 2), (1.5, 0), (-0.001, 2), (1e30, 2),
             (123.456, -1), (0.125, 2), (-2.5, 0)):
    show(lambda: round(g(v), n))
