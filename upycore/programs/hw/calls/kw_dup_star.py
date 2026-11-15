def f(**kw):
    return kw


try:
    print(f(a=1, **{"a": 2}))
except TypeError as e:
    print(type(e).__name__)
    print(e.args[0])

try:
    print(f(**{"a": 1}, **{"a": 2}))
except TypeError as e:
    print(type(e).__name__)
    print(e.args[0])


def g(a, **kw):
    return (a, kw)


try:
    print(g(a=1, **{"a": 2}))
except TypeError as e:
    print(type(e).__name__)
    print(e.args[0])

print(f(a=1, b=2))
print(f(**{"a": 1}, **{"b": 2}))
