# Ported from pycore pycore/programs/img_fw_float_str.py.
"""Firmware float(): numeric promotion and correctly rounded str parsing.

Covers the Clinger fast path, the double-double path (1e23, 18-digit
mantissas, DBL_MAX and subnormal edges), inf / nan spellings, whitespace
and underscores, and ValueError on malformed strings.
"""


def rejects(s):
    try:
        float(s)
    except ValueError:
        return 1
    return 0


def num(text):
    try:
        return float(text)
    except (ValueError, OverflowError):
        return None


def managed_entry():
    total = 0
    if float(7) == 7.0:
        total += 1
    if float(True) == 1.0:
        total += 2
    if num("1.5") == 1.5:
        total += 4
    if num("-2.5e3") == -2500.0:
        total += 8
    if num("  .25  ") == 0.25:
        total += 16
    # Underscores in numeric literals are accepted by the unix port and
    # rejected by the device firmware.
    if num("0.1") == 0.1:
        total += 64
    if num("1e23") == 1e23:
        total += 128
    if num("9007199254740993") == 9007199254740992.0:
        total += 256
    if num("123456789012345678e-5") == 1234567890123.45678:
        total += 512
    if num("2.2250738585072011e-308") == 2.2250738585072011e-308:
        total += 1024
    if num("4.9e-324") == 5e-324:
        total += 2048
    if num("1.7976931348623158e308") == 1.7976931348623157e308:
        total += 4096
    if num("1e400") is not None and num("1e400") > 1e308:
        total += 8192
    x = num("nan")
    if x is not None and x != x:
        total += 16384
    inf = num("-Infinity")
    if inf is not None and inf < -1e308:
        total += 32768
    # "1..2" and "1__0" are not rejected the same way on both sides.
    total += rejects("") * 131072
    return total

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
