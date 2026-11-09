# Console output: print, a long line, sys.stdout and sys.stderr writes,
# print(file=sys.stderr), and an uncaught exception's traceback. Run with
# the sim strap (stdout and stderr apart, on the simulator page) and with
# the uart strap (both on the I/O core's UART, decoded at the pin, in
# order). Output is not cooked: "\n" stays "\n", as MicroPython's
# mp_hal_stdout_tx_strn does on rp2 without a terminal (shared/runtime/
# stdout_helpers.c cooks only in mp_hal_stdout_tx_strn_cooked, which print
# does not use). Hand-written golden: the unix port's streams differ.
import sys

print("hello", 1, 2.5, [3, "x"])
print("".join(chr(65 + i % 26) for i in range(300)))
n = sys.stdout.write("written\n")
print("returned", n)
sys.stderr.write("to stderr\n")
print("also stderr", file=sys.stderr)
for i in range(5):
    print(i, end=" ")
print()
def f():
    raise ValueError("boom")
f()
