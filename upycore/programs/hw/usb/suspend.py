# Suspend and resume: the host stops SOF for 5 ms, so the device's SIE
# reports a suspend and TinyUSB calls tud_suspend_cb; resume signalling and
# SOF bring it back, and the console works on (suspend.usb).
import sys

while True:
    line = sys.stdin.readline()
    print('got', line.strip())
