class A:
    def f(self):
        return 1


class B(A):
    pass


class C(A):
    def f(self):
        return 2


class D(B, C):
    def f(self):
        return super().f()


print(D().f())
