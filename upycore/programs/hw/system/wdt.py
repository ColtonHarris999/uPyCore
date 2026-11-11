# machine.WDT (extmod/machine_wdt.c): fed, it keeps the program running;
# not fed for longer than its timeout, it resets the hart domain, and the
# next boot sees WDT_RESET. Hand-written golden.
import machine
import time

if machine.reset_cause() != machine.WDT_RESET:
    w = machine.WDT(timeout=5)
    for i in range(4):
        time.sleep_ms(2)
        w.feed()
    print("fed")
    time.sleep_ms(20)
    print("not reached")
else:
    print("watchdog reset", machine.reset_cause())
