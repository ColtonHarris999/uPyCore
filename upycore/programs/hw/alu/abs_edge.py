# abs() of every numeric kind: a float drops its sign bit (-0.0 and -nan
# become positive), a bool is an int, and ints keep their exact value.


def g(x):
    return x


for v in (g(-0.0), g(0.0), g(-2.5), g(2.5), g(float('-inf')), g(True), g(False),
          g(-5), g(5), g(-1073741824), g(-1073741825), g(-2147483648),
          g(-2 ** 40), g(-(2 ** 62)), g(2 ** 62)):
    print(repr(abs(v)))
print(abs(g(float('nan'))))
print(abs(g(complex(-3.0, 4.0))))
