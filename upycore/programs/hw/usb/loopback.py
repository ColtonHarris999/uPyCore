# 4 KB through the whole USB path: the host's bulk OUT, TinyUSB on the I/O
# core, CON_RX, sys.stdin on the hart, sys.stdout, CON, and bulk IN back to
# the host, which checks every byte in order and reports the rate
# (loopback.usb; the host model is iocore/tb/tb_usb_host.sv). Ctrl-C is
# disarmed so every byte is data. Ported from the epic branch's test.
import micropython
import sys

micropython.kbd_intr(-1)
n = 0
while n < 4096:
    s = sys.stdin.read(64)
    sys.stdout.write(s)
    n += len(s)
