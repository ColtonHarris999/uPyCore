# Suspend and resume: the host stops SOF for 5 ms, so the SIE reports a bus
# suspend and TinyUSB calls tud_suspend_cb; resume signalling and SOF bring
# it back, and the console works on (suspend.usb). Ported from the epic
# branch's test. Hand-written golden.
import sys

while True:
    line = sys.stdin.readline()
    print('got', line.strip())
