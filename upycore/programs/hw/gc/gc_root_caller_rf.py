import gc

# Ported from pycore pycore/programs/img_gc_root_caller_rf.py.
"""GC: caller RF slots below wm stay rooted (gc_plan.md §6.4).

A CALL that does not overflow the RF ring leaves the caller's locals in
slots below `rf_wm_r`. Those slots are not spilled, so a collection inside
the callee must still mark them. `keep` is reachable only from the caller's
RF; if the walker starts at wm it is freed and the return path traps or
returns garbage.
"""


def inner():
    gc.collect()
    drop = ["dropped-callee-temp-string"]
    drop = None
    gc.collect()
    return 1


def managed_entry():
    keep = [7, "only-reachable-from-caller-rf-slot"]
    n = inner()
    return n + keep[0] + len(keep[1])

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
