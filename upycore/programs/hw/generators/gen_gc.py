import gc


def deep(n, acc):
    a = [n, acc]
    b = (n, a)
    if n == 0:
        return acc
    return deep(n - 1, acc + len(b))


def hold():
    only = list(range(40))
    yield 0
    yield only[0]
    yield only[39]
    yield len(only)


def suspend():
    g = hold()
    print("suspend", next(g))
    print("deep", deep(36, 0))
    gc.collect()
    print("survived", next(g), next(g), next(g))
    return g


def managed_entry():
    g = suspend()
    gc.collect()
    held = gc.mem_free()
    g = None
    gc.collect()
    print("freed", gc.mem_free() > held)


try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
