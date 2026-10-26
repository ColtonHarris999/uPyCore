class A:
    def f(self):
        return "A"


class B(A):
    def f(self):
        return "B"


class C(A, B):
    pass


print(C().f())
