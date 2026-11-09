# A misaligned load in the bridge window is not a bridge access: mpy_soc
# leaves it to mpy_mem, which answers with the unaligned fault, and the
# core halts (upycore/docs/mpy_io_core.md, Bridge). Hand-written golden.
import _io

print("before")
_io.rd(2)
print("after")
