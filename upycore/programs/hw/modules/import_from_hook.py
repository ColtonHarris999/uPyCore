import sys
import builtins

orig = builtins.__import__


def f(name, globals, locals, fromlist, level):
    print("hook", name, fromlist, locals, level)
    # The recursive IMPORT_FROM load passes NULL globals. Do not read them.
    if fromlist is True:
        return orig(name, {}, locals, fromlist, level)
    return orig(name, globals, locals, fromlist, level)


builtins.__import__ = f
print(builtins.__import__ is orig)
from pkg_hook import sub
print(sub.VALUE)
try:
    from pkg_hook import nope
except ImportError as exc:
    print(type(exc).__name__, exc)
try:
    from sys import nope
except ImportError as exc:
    print(type(exc).__name__, exc)
