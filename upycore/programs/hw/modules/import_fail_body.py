import sys

try:
    import badmod
except ValueError as e:
    print("err", e)
print("cached", "badmod" in sys.modules)
try:
    import badmod
except ValueError as e:
    print("err2", e)
print("cached2", "badmod" in sys.modules)
