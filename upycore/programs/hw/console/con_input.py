# Console input: input() with a prompt and line editing, then sys.stdin
# read and readline. The uart run's line model types the bytes in the
# manifest; the sim run has no input, so input() raises EOFError as at the
# end of a stream (py/modbuiltins.c). Echo and editing follow
# shared/readline/readline.c (MicroPython v1.29.0): the second line ends
# in CR LF, readline takes the CR, and the LF stays for sys.stdin.read,
# as it does there. Hand-written golden.
import sys

try:
    s = input("name? ")
    print("got", repr(s))
    s = input()
    print("got", repr(s))
    print("read", repr(sys.stdin.read(3)))
    print("line", repr(sys.stdin.readline()))
except EOFError:
    print("EOFError")
