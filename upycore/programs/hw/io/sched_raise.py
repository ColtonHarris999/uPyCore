# A schedule callback that raises prints its traceback on stdout and does
# not unwind the program (mp_call_function_1_protected).
import micropython


def bad(x):
    raise ValueError(x)


micropython.schedule(bad, 5)
n = 0
while n < 2:
    n += 1
print('after', n)
micropython.schedule(bad, 6)
while n < 4:
    n += 1
print('done', n)
