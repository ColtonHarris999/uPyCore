# A word store to an offset the bridge does not implement (0x100) is a bus
# fault from mpy_mem, the same fault path as any memory access.
# Hand-written golden.
import _io

print("before")
_io.wr(0x100, 1)
_io.rd(0)
print("after")
