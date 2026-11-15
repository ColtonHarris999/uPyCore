print("%%" % ())
print("=%s=" % "str")
print("=%r=" % "str")


class A:
    def __int__(self):
        return 123


print("%d" % A())
print("foo" % {})
print("%(foo)s" % {"foo": "bar"})
try:
    print("%*s" % 5)
except TypeError:
    print("TypeError")
try:
    print("%(foo)*s" % {"foo": "bar"})
except TypeError:
    print("TypeError")
try:
    a = "%*" % 1
except ValueError:
    print("ValueError")
try:
    "%c" % "aa"
except TypeError:
    print("TypeError")
try:
    "%l" % 1
except ValueError:
    print("ValueError")
try:
    "a%" % 1
except ValueError:
    print("ValueError")
