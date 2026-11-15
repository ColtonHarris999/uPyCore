class Dummy(BaseException):
    pass


class Good(BaseException):
    def __new__(cls, *a, **k):
        return Dummy(*a, **k)


try:
    raise Good("good message")
except BaseException as g:
    print(type(g).__name__, g.args[0])


class BadException(BaseException):
    def __new__(cls, *args, **kwargs):
        print("BadException __new__")
        return 1


try:
    raise BadException("bad message")
except Exception as bad:
    print(type(bad).__name__)
    print(bad.args[0] if bad.args else "exceptions must derive from BaseException")


def gen():
    yield


try:
    gen().throw(BadException)
except Exception as genbad:
    print(type(genbad).__name__)
    print(genbad.args[0] if genbad.args else "exceptions must derive from BaseException")


class A:
    def __new__(cls):
        print("A.__new__")
        return super(cls, A).__new__(cls)

    def __init__(self):
        print("A.__init__")

    def meth(self):
        print("A.meth")


a = A()
a.meth()
a = A.__new__(A)
a.meth()
a = a.__new__(A)
a.meth()


class B:
    def __new__(self, v1, v2):
        print("B.__new__", v1, v2)

    def __init__(self, v1, v2):
        print("B.__init__", v1, v2)


print("B inst:", B(1, 2))


class D:
    pass


class C:
    def __new__(cls):
        print("C.__new__")
        return D()

    def __init__(self):
        print("C.__init__")


c = C()
print(isinstance(c, D))
print(type(c).__name__)
