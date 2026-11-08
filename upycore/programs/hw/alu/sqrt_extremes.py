# Exact power-of-two results: binary32 and binary64 have the same answers.
for n in range(-60, 61, 10):
    x = 2.0 ** n
    print(n, abs(complex(x, 0.0)) == x)
print('zero', abs(complex(0.0, 0.0)) == 0.0)
print('inf', abs(complex(float('inf'), 0.0)) == float('inf'))
z = abs(complex(float('nan'), 0.0))
print('nan', z != z)
