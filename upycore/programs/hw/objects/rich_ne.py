class X:
    def __eq__(s, o):
        print("eq")
        return True

    def __ne__(s, o):
        print("ne")
        return 5


a = X()
b = X()
print(a != b)
print(a == b)


class Y:
    def __ne__(s, o):
        print("Y ne")
        return True


print(Y() != 1)
print(1 != Y())


class E:
    def __eq__(self, other):
        print("E eq", other)
        return 123


print(E() == None)
print(None == E())
print(E() != 0)
print(0 != E())
print("a" == E())
print(E() == E())


class F:
    def __ne__(self, other):
        print("F ne", other)
        return -456


print(E() != F())
print(F() != E())
print(F() == 1)
print(1 == F())
