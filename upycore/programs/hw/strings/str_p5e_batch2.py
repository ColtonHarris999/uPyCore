# Ported from pycore pycore/programs/img_str_p5e_batch2.py.
"""P5e batch 2+: JOIN, TRIM, CLASSIFY, MAP, PAD, AFFIX, ZFILL via STRACC.

Expected is computed by the host image builder from managed_entry().
"""


def managed_entry():
    n = 0
    a = "a"
    b = "b"
    if "-".join([a, b]) == "a-b":
        n = n + 1
    if "  hi  ".strip() == "hi":
        n = n + 2
    if "  hi  ".lstrip() == "hi  ":
        n = n + 4
    if "  hi  ".rstrip() == "  hi":
        n = n + 8
    if "Ab".upper() == "AB":
        n = n + 16
    if "Ab".lower() == "ab":
        n = n + 32
    # swapcase, isascii, ljust, rjust, removeprefix, removesuffix, zfill,
    # capitalize, title, casefold, istitle, isdecimal, isnumeric, and
    # isprintable are not str methods here.
    if "12".isdigit():
        n = n + 128
    if "abc".islower():
        n = n + 512
    if "ABC".isupper():
        n = n + 1024
    if "hi".center(6) == "  hi  ":
        n = n + 2048
    if "xxhiyy".strip("xy") == "hi":
        n = n + 33554432
    if "".join(["x"]) == "x":
        n = n + 67108864
    if "-".join("ab") == "a-b":
        n = n + 134217728
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
