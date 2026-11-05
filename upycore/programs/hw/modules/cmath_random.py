# cmath and random (frozen runtime modules). random is a bit-exact yasmarang
# port, so seeded sequences match; unseeded state differs by design (the
# oracle seeds itself on import).
import cmath, random
w = cmath.exp(1j)
print(cmath.pi, cmath.e, cmath.rect(2, 0.5), cmath.rect(1, 0), cmath.exp(0), '%.6g %.6g' % (w.real, w.imag))
z = cmath.rect(3, -2)
print('%.6g %.6g' % (z.real, z.imag))
for sd in (0, 1, 1234, 0xFFFFFFFF, -5):
    random.seed(sd)
    print(sd, random.getrandbits(32), random.getrandbits(5), random.getrandbits(0),
          [random.randrange(10) for i in range(6)], random.randrange(5, 105), random.randrange(-10, 100, 7),
          random.randrange(100, -10, -3), random.randint(-5, 5), random.choice('abcdefg'), random.random(),
          '%.5f' % random.uniform(2, 9.5))
random.seed(1234)
print(sum(random.randrange(1 << 20) for i in range(200)))
for name, a in (('randrange', (0,)), ('randrange', (5, 5)), ('randrange', (1, 5, 0)),
                ('randint', (3, 2)), ('choice', ([],)), ('getrandbits', (33,)),
                ('seed', (1.5,)), ('randrange', (1.5,))):
    try:
        print(name, getattr(random, name)(*a))
    except Exception as e:
        print(name, a, type(e).__name__, e)
