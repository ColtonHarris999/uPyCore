# Three-argument pow with a missing modulus, a non-str hasattr name,
# and an __int__ that does not return an int.
print(pow(3, 4, 7))
print(pow(0, 1, None))
print(pow(-2, 3, None))
try:
    pow(4, 5, "z")
except TypeError:
    print("pow TypeError")

try:
    hasattr(1, b"123")
except TypeError:
    print("hasattr bytes")
try:
    hasattr(1, 123)
except TypeError:
    print("hasattr int")
print(hasattr("abc", "find"))

class BadInt:
    def __int__(self):
        return None

try:
    int(BadInt())
except TypeError:
    print("int TypeError")

class GoodInt:
    def __int__(self):
        return 42

print(int(GoodInt()))
