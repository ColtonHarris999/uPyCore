# Ported from pycore pycore/programs/img_firmware_wave3_pow.py.
"""Extra pow / divmod / min coverage (single-core). Host golden: 169."""


def managed_entry():
    total = 0
    total += pow(2, 0)
    total += pow(5, 1)
    total += pow(2, 10, 1000)
    q, r = divmod(100, 7)
    total += q * 10 + r
    total += min(0, 0)
    total += min(-3, 2)
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
