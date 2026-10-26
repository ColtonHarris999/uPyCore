import sys
import usys
import builtins

print(usys is sys)
print(builtins.len is len)
print(type(builtins).__name__)
