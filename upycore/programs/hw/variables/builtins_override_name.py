import builtins


def f(x):
    return 7


print(len("ab"))
builtins.len = f
print(len("ab"))
print(builtins.len("ab"))
del builtins.len
print(len("ab"))
print(builtins.len is len)
