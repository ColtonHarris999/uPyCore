def take_str():
    return "ab"[::2]


def take_bytes():
    return b"ab"[::2]


def take_tuple():
    return (1, 2)[::2]


def take_bytearray():
    return bytearray(b"ab")[::2]


def check(label, fn):
    try:
        fn()
    except NotImplementedError as e:
        print(label, type(e).__name__, e)
    else:
        print(label, "no-error")


check("str", take_str)
check("bytes", take_bytes)
check("tuple", take_tuple)
check("bytearray", take_bytearray)
