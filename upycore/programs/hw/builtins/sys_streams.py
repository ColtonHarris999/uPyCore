# sys.stdout and sys.stderr, and print(file=...): to the streams; an object
# that only has a write method is not a stream.
import sys

print(sys.stdout, sys.stderr, sys.stdin)
print(sys.stdout.write('abc\n'))
print('to stdout', 1, file=sys.stdout)
print('to stderr', 2, file=sys.stderr)
sys.stderr.write('direct\n')


class W:
    def __init__(self):
        self.parts = []

    def write(self, s):
        self.parts.append(s)


w = W()
try:
    print('x', 'y', sep='-', end='!', file=w)
except OSError as e:
    print('OSError', e)
print(w.parts)
print(sys.stdout is sys.stdout)
