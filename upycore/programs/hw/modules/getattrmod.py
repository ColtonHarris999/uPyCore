sentinel = 3


def __getattr__(name):
    if name == "missing":
        return 5
    raise AttributeError(name)
