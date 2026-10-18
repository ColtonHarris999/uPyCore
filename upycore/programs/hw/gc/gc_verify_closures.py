import gc

# Ported from pycore pycore/programs/img_gc_verify_closures.py.
def make_counter(start):
    count = [start]
    def inc(step):
        count[0] = count[0] + step
        return count[0]
    return inc

def adder(n):
    return lambda x: x + n

"""GC: closures, cells, and function objects (gc_plan.md Phase 0).

Closures only come from the on-device compiler, so the source is compiled on
PyCore. A counter closure keeps its cell alive through the FUNCTION object's
closure tuple; discarded closures and their cells become garbage, as does
the compiler's working set.
"""



def managed_entry():
    c = make_counter(5)
    f = adder(7)
    mk = make_counter
    garbage = [mk(0), mk(1), mk(2), mk(3), mk(4)]
    garbage = None
    gc.collect()
    c(3)
    total = c(4) + f(1)
    gc.collect()
    return total + c(0)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
