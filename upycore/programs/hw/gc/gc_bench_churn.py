# Ported from pycore pycore/programs/img_gc_bench_churn.py.
"""G13 benchmark: allocation churn with the heap about 3x the live data (gc_plan.md G13 P6b).

A live table of ~24 KB stays reachable while each iteration allocates and
drops short-lived objects; the Makefile target sizes the dynamic heap to
about three times the live bytes, so collections are frequent.
"""


def managed_entry():
    live = [0] * 40
    for i in range(40):
        live[i] = (i, "live-entry-string-" + str(i))
    total = 0
    for i in range(60):
        t = [i, (i, i + 1), "churn-string-number-" + str(i)]
        u = {"k": t, "n": i}
        total = total + len(t[2]) % 5 + u["n"] % 3 + live[i % 40][0] % 2
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
