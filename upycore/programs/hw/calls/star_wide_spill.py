# An opcode runs with at most RF_SPILL_AT-1 resident slots. f(*seq, six
# keywords) is the callable, the star, 12 keyword words, and the bitmap:
# 15 words, one past that window, so the conversion writes a spill chunk.


def f(*a, **k):
    return (len(a), a[0], a[-1], len(k), k["k5"])


class Seq:
    def __iter__(self):
        return iter((7, 8, 9))


print(f(*Seq(), k0=0, k1=1, k2=2, k3=3, k4=4, k5=5))
print(f(*b"ab", k0=0, k1=1, k2=2, k3=3, k4=4, k5=5))
