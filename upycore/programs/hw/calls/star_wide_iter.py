# The call is the callable, 13 positionals, and the star bitmap (15 words).
# That is wider than the resident window, and the star is still in a
# register: a value that is not a tuple or list is turned into a tuple
# with ABI_CONT_REPLACE, then the opcode runs again.


def f(*a):
    return (len(a), a[0], a[11], a[-2], a[-1])


def call(seq):
    return f(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, *seq)


class Seq:
    def __iter__(self):
        return iter((7, 8, 9))


print(call(range(3)))
print(call(Seq()))
print(call(b"ab"))
