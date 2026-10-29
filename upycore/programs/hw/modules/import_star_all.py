from starred import *

print(a)
print(_d)
try:
    print(b)
except NameError:
    print("no-b")
from plainstar import *
print(p)
try:
    print(_c)
except NameError:
    print("no-c")
