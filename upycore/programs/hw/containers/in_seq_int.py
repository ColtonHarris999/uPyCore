# `int in list/tuple`: the core scans for a small int, and leaves floats,
# big ints, complex numbers and objects with __eq__ to the firmware.
class Eq:
    def __eq__(self, other):
        return other == 3


seqs = [[], [1, 2, 3], (4, 5, 6), [True], [False, None], ['1', b'1', (1,), [1], {1: 1}, {1}, range(1, 2), None],
        [1.0], [2 ** 40, 7], [1 + 0j], [Eq()], (0.5, 3), [-1, -2 ** 30, 2 ** 30 - 1]]
needles = [0, 1, 3, 5, 7, -1, -2 ** 30, 2 ** 30 - 1]
for s in seqs:
    print([n in s for n in needles], [n not in s for n in (1, 3)])
big = list(range(0, 300, 3))
print(sum(1 for n in range(300) if n in big), 299 in big, 297 in tuple(big))
