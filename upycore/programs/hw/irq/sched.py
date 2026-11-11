# micropython.schedule: a real deferral. Callbacks run at soft points (the
# jumps py/vm.c checks pending work at), at most one per soft point, in
# order (py/scheduler.c); the ninth schedule with eight waiting raises
# RuntimeError("schedule queue full") (py/modmicropython.c, depth 8 as on
# rp2); an exception in a scheduled callback is printed on stdout and the
# program goes on (mp_call_function_1_protected). Hand-written golden: the
# unix oracle is not built in this tree, and its scheduler depth is 4.
import micropython

out = []


def cb(x):
    out.append(x)


micropython.schedule(cb, 1)
micropython.schedule(cb, 2)
print("before any soft point", out)
for i in range(4):
    pass
print("after a loop", out)

out.clear()
micropython.schedule(cb, 10)
micropython.schedule(cb, 11)
micropython.schedule(cb, 12)
micropython.schedule(cb, 13)
micropython.schedule(cb, 14)
micropython.schedule(cb, 15)
micropython.schedule(cb, 16)
micropython.schedule(cb, 17)
try:
    micropython.schedule(cb, 18)
except RuntimeError as e:
    print("RuntimeError:", e)
for i in range(10):
    pass
print(out)


def bad(x):
    raise ValueError("in callback %d" % x)


micropython.schedule(bad, 7)
micropython.schedule(cb, 99)
for i in range(3):
    pass
print("still running", out[-1])
