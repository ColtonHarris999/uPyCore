import gc

# Ported from pycore pycore/programs/img_gc_root_frames.py.
"""GC: frame-descriptor roots (gc_plan.md §6.4 root_caller_frame, root_saved_globals,
root_ctor_instance).

- A caller's code object is reachable only from its frame descriptor: the
  compiled `g` is popped out of its namespace and called directly, so while
  its callee `h` collects, nothing else references `g`'s code.
- A globals dict passed to exec is reachable only as the running frame's
  globals.
- `__init__` collects while the new instance is held by the frame.
"""

SRC = """\
def g(n):
    r = h(n)
    return len(r[1]) + r[0]
"""

EXEC_SRC = "gc.collect()\nout[0] = len(payload[1]) + payload[0]\n"


def h(n):
    gc.collect()
    junk = [n, n, n]
    junk = None
    gc.collect()
    return [n, "callee-result-list"]


class Built:
    def __init__(self, n):
        gc.collect()
        self.n = n
        self.s = "constructed-instance-" + str(n)


def managed_entry():
    ns = {"h": h}
    exec(compile(SRC, "<s>", "exec"), ns)
    a = ns.pop("g")(4)
    ns = None
    out = [0]
    exec(compile(EXEC_SRC, "<e>", "exec"),
         {"out": out, "payload": [3, "exec-globals-owned-string"], "gc": gc})
    b = Built(9)
    gc.collect()
    return a * 10000 + out[0] * 100 + b.n + len(b.s)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
