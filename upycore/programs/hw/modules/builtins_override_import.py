import sys
import builtins

orig = builtins.__import__


def f(name, globals, locals, fromlist, level):
    print("hook", name, fromlist, locals, level)
    return orig(name, globals, locals, fromlist, level)


builtins.__import__ = f
print(builtins.__import__ is orig)
import usys
print(usys is sys)
