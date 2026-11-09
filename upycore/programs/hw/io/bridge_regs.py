# The bridge's registers and state page end to end (mpy_iobr, iocore/sw/fw):
# EVT set by the I/O core and by EVT_SET, cleared by writing 1s; a page
# word written by the I/O core (CH_PAGE) appears in the hart's copy; a
# hart page word (0xC00) reads back and reaches the I/O core (CH_DNRD);
# PING answers the protocol version. Hand-written golden.
import machine

B = 0x40000000
m = machine.mem32
CMD, RSP, STATUS, EVT, EVT_EN, EVT_SET, EVT_MASK, IOC_CTRL, CON_RX, CON_MODE = (
    B, B + 4, B + 8, B + 12, B + 16, B + 20, B + 24, B + 28, B + 32, B + 36)


def rsp():
    while m[STATUS] >= 0:
        pass
    return m[RSP]


m[CMD] = 0x01010000            # SYS PING
print("version", rsp())
print("page0", hex(m[B + 0x800]))
print("con_mode", m[CON_MODE], "con_rx", m[CON_RX])

# Events: the I/O core raises bits 4 and 2.
m[CMD] = 0x03000014
m[CMD] = 0x02000001
rsp()                          # the echo comes after the event push
n = 0
while m[EVT] & 0x14 != 0x14 and n < 100:
    n += 1
print("evt", hex(m[EVT]))
m[EVT_SET] = 0x101
print("evt", hex(m[EVT]))
m[EVT] = 0x14
print("evt", hex(m[EVT]))
m[EVT] = 0x101
print("evt", hex(m[EVT]))
m[EVT_EN] = 0x5
m[EVT_MASK] = 1
print("en", m[EVT_EN], "mask", m[EVT_MASK])
m[EVT_MASK] = 0
m[EVT_EN] = 0

# A page word written by the I/O core: CH_PAGE index 20 (a word the
# firmware does not use), then the value.
m[CMD] = 0x04000014
m[CMD] = 0x12345678
rsp()
n = 0
while m[B + 0x800 + 80] != 0x12345678 and n < 100:
    n += 1
print("page20", hex(m[B + 0x800 + 80]))
m[CMD] = 0x0400001F
m[CMD] = -2
rsp()
n = 0
while m[B + 0x800 + 124] != -2 and n < 100:
    n += 1
print("page31", m[B + 0x800 + 124])

# Hart page words: they read back here and reach the I/O core.
for j in range(8):
    m[B + 0xC00 + 4 * j] = 0x1000 * j + j
print("dn", [hex(m[B + 0xC00 + 4 * j]) for j in range(8)])
out = []
for j in range(8):
    m[CMD] = 0x05000000 | j
    out.append(hex(rsp()))
print("dn at the I/O core", out)
st = m[STATUS]
print("status", hex(st & 0x7FFFFFFF))
