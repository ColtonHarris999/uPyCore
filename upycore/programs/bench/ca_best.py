# Best case for the container accelerator's scoreboard (upycore/docs/mpy_ca.md).
#
# Each round ships one 8192-word copy and then runs independent work that
# touches only locals, so the core never waits for the copy and leaves the
# memory port to the accelerator. c already has room for a, so the copy
# needs no allocation (an allocation zeroes every new word on both paths).
# WORK is sized so the work takes about as long as the accelerator's copy.
# The copy is read only after the work, when it has landed.

N_LOG2 = 13      # 8192 words
WORK = 296
ROUNDS = 16


def kernel(a, c, rounds, work):
    acc = 0
    r = 0
    while r < rounds:
        c.clear()
        c.extend(a)            # one _wcopy, shipped to the accelerator
        x = r
        k = 0
        while k < work:        # locals only: no access to a or c
            x = (x * 5 + k) & 0x3FFF
            k += 1
        acc += x + c[r] + c[-1 - r] + len(c)
        r += 1
    return acc


# Doubling builds the source with bulk copies; a per-item build would
# cost more than the kernel.
a = list(range(64))
while len(a) < (1 << N_LOG2):
    a.extend(a)
c = a.copy()
print(len(a), kernel(a, c, ROUNDS, WORK))
print(c[0], c[4097], c[-1])
