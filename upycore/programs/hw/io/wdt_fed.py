# Fed every tick, a 5-tick watchdog never fires across 30 ticks.
import machine
import time

w = machine.WDT(timeout=5)
for i in range(30):
    time.sleep_ms(1)
    w.feed()
print('fed', machine.reset_cause() == machine.PWRON_RESET, machine.mem32[0x4000050C])
