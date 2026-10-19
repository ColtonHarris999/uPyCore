# On-device compile of yield, yield from, a generator expression, send,
# and a generator that closes over a cell.
Y = """\
def gy(n):
    yield n
    yield n + 1
"""

F = """\
def gf():
    yield from (1, 2, 3)
"""

E = """\
def ge():
    t = 0
    for v in (x * x for x in (1, 2, 3)):
        t = t + v
    return t
"""

S = """\
def gs():
    x = yield 1
    yield x + 3
"""

C = """\
def outer(n):
    def g():
        yield n
        yield n + 2
    return g
"""


def managed_entry():
    ns = {}
    exec(compile(Y, "<y>", "exec"), ns)
    a = 0
    for v in ns["gy"](4):
        a = a + v
    exec(compile(F, "<f>", "exec"), ns)
    b = 0
    for v in ns["gf"]():
        b = b + v
    exec(compile(E, "<e>", "exec"), ns)
    c = ns["ge"]()
    exec(compile(S, "<s>", "exec"), ns)
    it = ns["gs"]()
    d = next(it)
    e = it.send(10)
    exec(compile(C, "<c>", "exec"), ns)
    f = 0
    for v in ns["outer"](6)():
        f = f + v
    return a + b + c + d + e + f

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
