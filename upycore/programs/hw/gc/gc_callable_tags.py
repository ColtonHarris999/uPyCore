import gc


def make(value):
    def leaf():
        return value
    return leaf


def indirect(fun):
    def call():
        return fun()
    return call


class Counter:
    def get(self):
        return 13


def generator(fun):
    yield fun()


def check():
    refs = [make(3)]
    keys = {make(5): 'live'}
    closed = indirect(make(7))
    bound = Counter().get
    stream = generator(make(11))
    gc.collect()
    assert refs[0]() == 3
    for key in keys:
        assert key() == 5 and keys[key] == 'live'
    assert closed() == 7
    assert next(stream) == 11
    assert bound() == 13


check()
print('callable roots ok')
