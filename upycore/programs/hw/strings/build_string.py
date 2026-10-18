# Ported from pycore pycore/programs/img_build_string.py.
"""BUILD_STRING of three SHORT_STR pieces without FORMAT.

Equivalent pieces of an f-string with already-string parts.
\"ab\"+\"cd\"+\"ef\" via f\"{a}{b}{c}\" → length 6.
"""


def managed_entry():
    a = "ab"
    b = "cd"
    c = "ef"
    s = f"{a}{b}{c}"
    out = 0
    for _ in s:
        out += 1
    return out

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
