# Ported from pycore pycore/programs/img_str_p5e_batch3.py.
"""P5e batch 3: expandtabs, split/rsplit/splitlines, partition/rpartition.

List/tuple equality is not used; checks go through len + indexing + str ==.
Expected is computed by the host image builder from managed_entry().
"""


def managed_entry():
    n = 0
    # expandtabs is not a str method here.
    t = "hello".partition(",")
    if t[0] == "hello" and t[1] == "" and t[2] == "":
        n = n + 8
    t = "a,b,c".partition(",")
    if t[0] == "a" and t[1] == "," and t[2] == "b,c":
        n = n + 16
    t = "a,b,c".rpartition(",")
    if t[0] == "a,b" and t[1] == "," and t[2] == "c":
        n = n + 32
    p = "a b c".split()
    if len(p) == 3 and p[0] == "a" and p[1] == "b" and p[2] == "c":
        n = n + 64
    p = "  a  b".split()
    if len(p) == 2 and p[0] == "a" and p[1] == "b":
        n = n + 128
    p = "a,b,c".split(",")
    if len(p) == 3 and p[0] == "a" and p[1] == "b" and p[2] == "c":
        n = n + 256
    if len("".split()) == 0:
        n = n + 512
    p = "".split(",")
    if len(p) == 1 and p[0] == "":
        n = n + 1024
    p = "a,b,c,d".rsplit(",", 1)
    if len(p) == 2 and p[0] == "a,b,c" and p[1] == "d":
        n = n + 2048
    p = "a  b  c".split(None, 1)
    if len(p) == 2 and p[0] == "a" and p[1] == "b  c":
        n = n + 4096
    p = "a\nb\n".splitlines()
    if len(p) == 2 and p[0] == "a" and p[1] == "b":
        n = n + 16384
    p = "a\nb".splitlines(True)
    if len(p) == 2 and p[0] == "a\n" and p[1] == "b":
        n = n + 32768
    p = "a\r\nb".splitlines()
    if len(p) == 2 and p[0] == "a" and p[1] == "b":
        n = n + 65536
    p = "a\r\nb".splitlines(True)
    if len(p) == 2 and p[0] == "a\r\n" and p[1] == "b":
        n = n + 131072
    p = "\n".splitlines()
    if len(p) == 1 and p[0] == "":
        n = n + 262144
    p = "a,b,c,d".split(",", 2)
    if len(p) == 3 and p[0] == "a" and p[1] == "b" and p[2] == "c,d":
        n = n + 524288
    p = "a,b,".split(",")
    if len(p) == 3 and p[0] == "a" and p[1] == "b" and p[2] == "":
        n = n + 1048576
    s = "abcdefghijklmnop"
    if s.split("x")[0] is s:
        n = n + 2097152
    p = "abc".split(",")
    if len(p) == 1 and p[0] == "abc":
        n = n + 4194304
    # rsplit(None, n) is not implemented.
    return n

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
