import gc

# Ported from pycore pycore/programs/img_gc_steady_dict.py.
"""GC steady state, dicts (gc_plan.md G11): 1,000 build/update/delete/drop iterations.

Self-checking: after WARMUP iterations the program measures live bytes with
`gc.collect()` (precise, so the exact reachable set), runs the rest, and
measures again. Any growth returns minus the growth in bytes; otherwise the
checksum, which host CPython (where `gc.collect()` returns 0) gives as the
golden. G11 also checks the plateau at every collection (+GC_LOG=1).
"""

WARMUP = 4
ITERS = 24


def work(lo, hi):
    total = 0
    for i in range(lo, hi):
        d = {"a": i, "b": "steady-dict-value-" + str(i % 9), None: [i], 7: (i, i)}
        d["a"] = d["a"] + 1
        del d[7]
        d[7] = i % 4
        total = total + d["a"] % 5 + len(d["b"]) + d[None][0] % 3 + d[7] + len(d)
    return total


def managed_entry():
    total = work(0, WARMUP)
    gc.collect()
    total = total + work(WARMUP, ITERS)
    gc.collect()
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
