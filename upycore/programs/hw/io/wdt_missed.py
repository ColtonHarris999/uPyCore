# A watchdog that is never fed resets the system after its timeout; the
# program runs again from the top with reset_cause() WDT_RESET.
import machine

c = machine.reset_cause()
print('cause', c)
if c == machine.PWRON_RESET:
    w = machine.WDT(timeout=5)
    print('armed')
    while True:
        machine.idle()
print('after the reset', c == machine.WDT_RESET)
