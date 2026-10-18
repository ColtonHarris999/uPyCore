# Ported from pycore pycore/programs/img_fw_pow_mulmod.py.
"""Firmware pow(base, exp, mod): CPython long_pow semantics on int64.

Sign of the result follows mod, pow(x, 0, 1) == 0, moduli above 2 ** 31 go
through the overflow-safe doubling mulmod, mod == 0 raises ValueError.
"""


def managed_entry():
    total = 0
    total += pow(2, 10, 1000)
    total += pow(2, 3, -5) + 10
    total += pow(7, 0, 1) * 10000
    total += pow(-5, 3, 7) * 10000
    # A negative exponent with a modulus is not an integer inverse here, and
    # a large exponent overflows long-long storage. Those cases are omitted.
    try:
        pow(2, 1, 0)
    except (ValueError, ZeroDivisionError):
        total += 10000000000
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
