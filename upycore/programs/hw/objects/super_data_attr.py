class A:
    bar = 123

    def foo(self):
        return [1, 2, 2]


class B(A):
    def foo(self):
        print(super().bar)
        return super().foo().count(2)


print(B().foo())


class C(B):
    def foo(self):
        print(super().bar)
        return super().foo()


print(C().foo())
