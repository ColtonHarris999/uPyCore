src = """
def f(n):
    s = 0
    for i in range(n):
        s += i
    return s

class A:
    def m(self, x):
        try:
            return x // self.d
        except ZeroDivisionError:
            return -1

a = A()
a.d = 2
print(f(5), a.m(7))
a.d = 0
print(a.m(7))
"""
exec(compile(src, "<m>", "exec"))
