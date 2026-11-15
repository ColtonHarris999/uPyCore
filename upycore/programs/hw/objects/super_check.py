# super() checks its arguments and prints the class and the object.
class A:
    bar = 123

    def show(self):
        print(str(super())[:18])

class B(A):
    def foo(self):
        return super().bar

print(B().foo())
B().show()

try:
    super(str, 0)
except TypeError:
    print("instance")
try:
    super(str, int)
except TypeError:
    print("subclass")
try:
    super(0, int)
except TypeError:
    print("not a type")
print(super(B, B()).bar)
