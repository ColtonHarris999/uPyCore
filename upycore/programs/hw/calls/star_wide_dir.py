# 251 blocks of 16 values fit in the argument-buffer pointer slots.
# Value 4016 is the first item of the next block, so the directory is
# the tuple in slot 4. The last value is 9 so a dropped block cannot
# pass as a run of ones.


def f(*a):
    return (len(a), a[0], a[15], a[4015], a[4016])


base = (1,) * 4016
print(f(*(base + (9,))))
