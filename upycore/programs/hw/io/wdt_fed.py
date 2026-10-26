# Fed every tick, a 5-tick watchdog never fires across 30 ticks.
import machine
import time

count = machine.mem32
w = machine.WDT(timeout=5)
for i in range(30):
    time.sleep_ms(1)
    w.feed()
n = count[0x4000050C]
print('fed', machine.reset_cause() == machine.PWRON_RESET, n)
