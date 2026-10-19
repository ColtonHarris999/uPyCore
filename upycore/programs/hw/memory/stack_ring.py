# Values are computed so the 80-element tuple is built on the operand
# stack. Slots 0 and 15 land in the oldest chunk, 16 and 31 in the next.
def build(n):
    return (n+0, n+1, n+2, n+3, n+4, n+5, n+6, n+7, n+8, n+9, n+10, n+11, n+12, n+13, n+14, n+15, n+16, n+17, n+18, n+19, n+20, n+21, n+22, n+23, n+24, n+25, n+26, n+27, n+28, n+29, n+30, n+31, n+32, n+33, n+34, n+35, n+36, n+37, n+38, n+39, n+40, n+41, n+42, n+43, n+44, n+45, n+46, n+47, n+48, n+49, n+50, n+51, n+52, n+53, n+54, n+55, n+56, n+57, n+58, n+59, n+60, n+61, n+62, n+63, n+64, n+65, n+66, n+67, n+68, n+69, n+70, n+71, n+72, n+73, n+74, n+75, n+76, n+77, n+78, n+79)

def big():
    a0 = 1
    a1 = 2
    a2 = 3
    a3 = 4
    a4 = 5
    a5 = 6
    a6 = 7
    a7 = 8
    a8 = 9
    a9 = 10
    a10 = 11
    a11 = 12
    a12 = 13
    a13 = 14
    a14 = 15
    a15 = 16
    a16 = 17
    a17 = 18
    a18 = 19
    a19 = 20
    a20 = 21
    a21 = 22
    a22 = 23
    a23 = 24
    a24 = 25
    a25 = 26
    a26 = 27
    a27 = 28
    a28 = 29
    a29 = 30
    a30 = 31
    a31 = 32
    a32 = 33
    a33 = 34
    a34 = 35
    a35 = 36
    a36 = 37
    a37 = 38
    a38 = 39
    a39 = 40
    a40 = 41
    a41 = 42
    a42 = 43
    a43 = 44
    a44 = 45
    a45 = 46
    a46 = 47
    a47 = 48
    a48 = 49
    a49 = 50
    a50 = 51
    a51 = 52
    a52 = 53
    a53 = 54
    a54 = 55
    a55 = 56
    a56 = 57
    a57 = 58
    a58 = 59
    a59 = 60
    a60 = 61
    a61 = 62
    a62 = 63
    a63 = 64
    a64 = 65
    a65 = 66
    a66 = 67
    a67 = 68
    a68 = 69
    a69 = 70
    a70 = 71
    a71 = 72
    a72 = 73
    a73 = 74
    a74 = 75
    a75 = 76
    a76 = 77
    a77 = 78
    a78 = 79
    a79 = 80
    return a0 + a79

t = build(0)
print(t[0])
print(t[15])
print(t[16])
print(t[31])
print(t[32])
print(t[79])
print(big())
