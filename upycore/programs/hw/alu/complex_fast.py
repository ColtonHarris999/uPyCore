# Complex +, -, * and abs() with complex and float operands (the core's
# ALU path), next to the operand kinds that still take the firmware.
inf = float('inf')
nan = float('nan')
vals = [1.5 + 2.25j, complex(-0.0, 0.0), complex(0.0, -0.0), complex(inf, 1.0),
        complex(1.0, nan), 3e38 + 3e38j, 0.1 + 0.7j]
floats = [-0.0, 2.5, inf, nan]
for i, a in enumerate(vals):
    for b in vals[i:]:
        print(a + b, a - b, a * b)
    for f in floats:
        print(a + f, f + a, a - f, f - a, a * f, f * a)
    print(abs(a))
# int, bool and int64 operands
for a in vals[:3]:
    print(a + 1, 2 * a, a - True, a * (1 << 40), (1 << 40) + a)
# in-place forms
z = 0
c = -0.75 + 0.125j
for i in range(6):
    z = z * z + c
    print(i, z, abs(z))
w = 1 + 1j
w += 2.0
w -= 0.5j
w *= w
print(w)
# results are new objects
p = 1 + 2j
q = p * 1.0
print(q == p, q is p)
