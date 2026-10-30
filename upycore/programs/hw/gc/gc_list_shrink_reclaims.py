import gc


def fill(a):
    a.append(bytearray(40000))


def tidy():
    for i in range(20):
        x = [i]
        # Exercise append on an unrelated list to replace native temporaries;
        # this test measures stale capacity slots, not conservative scratch roots.
        x.append(None)
    gc.collect()
    gc.collect()


def check(mode):
    a = []
    fill(a)
    if mode == 0:
        a.clear()
    elif mode == 1:
        a.pop()
    elif mode == 2:
        del a[0]
    else:
        a[:] = []
    tidy()
    free = gc.mem_free()
    a.append(None)
    tidy()
    # Overwriting a dead capacity slot must not release the removed object.
    assert gc.mem_free() - free < 1024
    print('reclaimed', mode)


for mode in range(4):
    check(mode)
    tidy()
