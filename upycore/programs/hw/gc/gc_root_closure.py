import gc

# Ported from pycore pycore/programs/img_gc_root_closure.py.
def outer(k):
    def mid(x):
        y = x + k
        def inner():
            return y + k
        return inner()
    return mid

"""GC: a closure's cells survive a collection before COPY_FREE_VARS (gc_plan.md §6.4).

`mid` is created first, then the heap is filled. The only reference is popped
out of a dict immediately before CALL, so the FUNCTION is not in a local.
`mid` has a free variable (`k`) and its own cell (`y`), so its first
instruction is MAKE_CELL. Leftover < 128 B makes that allocation abort while
the closure tuple is held only by `cur_closure_r`.
"""



def managed_entry():
    keep = outer(100)
    box = {}
    box["m"] = outer(7)
    ns = None
    junk = None
    r = box.pop("m")(5)
    gc.collect()
    return r * 1000 + keep(1)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
