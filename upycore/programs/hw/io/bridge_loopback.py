# 1,000 words through the bridge and back: CMD to the I/O core, which
# answers each ECHO word unchanged in RSP (iocore/sw/fw, CH_ECHO).
# Hand-written golden: the unix port has no machine module.
import machine

BASE = 0x40000000
CMD, RSP, STATUS, IOC_CTRL = BASE, BASE + 4, BASE + 8, BASE + 0x1C
m = machine.mem32
print("ioc_ctrl", m[IOC_CTRL])

def roundtrip(n):
    sent = 0
    got = 0
    bad = 0
    acc = 0
    while got < n:
        # Keep up to 8 words in flight; RSP holds 16.
        if sent < n and sent - got < 8:
            m[CMD] = 0x02000000 | sent
            sent += 1
        if m[STATUS] < 0:            # bit 31: RSP not empty
            w = m[RSP]
            if w != (0x02000000 | got):
                bad += 1
            acc = (acc + w) & 0xFFFFFF
            got += 1
    return got, bad, acc

got, bad, acc = roundtrip(1000)
print("words", got, "bad", bad, "sum", hex(acc))
# Channel bits above bit 30: an ECHO word with every bit pattern in the payload.
m[CMD] = 0x02FFFFFF
while m[STATUS] >= 0:
    pass
print(hex(m[RSP] & 0xFFFFFFFF))
