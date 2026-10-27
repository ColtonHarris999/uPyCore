# 4 KB through the whole path: the host's bulk OUT, TinyUSB, the mailbox,
# sys.stdin on the hart, sys.stdout, the mailbox, and bulk IN back to the
# host, which checks every byte and reports the rate (loopback.usb). Ctrl-C
# is disarmed so every byte is data.
import micropython
import sys

micropython.kbd_intr(-1)
n = 0
while n < 4096:
    s = sys.stdin.read(64)
    sys.stdout.write(s)
    n += len(s)
sys.stdin.read(1)
