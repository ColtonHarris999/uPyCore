# The UART console (+CONSOLE=uart): print, input with its echo,
# sys.stdin.readline, stderr, and an uncaught traceback all go over the
# UART; the bench writes its TX bytes to stdout. Input arrives while the
# program waits in idle.
import sys

print('hello on the uart')
name = input('name? ')
print('hi', name)
print(repr(sys.stdin.readline()))
sys.stderr.write('err line\n')
try:
    1 / 0
except ZeroDivisionError as e:
    print('caught', e)
raise ValueError('uncaught')
