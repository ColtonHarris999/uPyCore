# machine.reset and reset_cause (extmod/modmachine.c names): a hard reset
# restarts the hart domain and puts the I/O core's peripherals back to
# their reset state, the watchdog included, as a chip's reset does. The
# watchdog started before it would have reset the hart 5 ms into the second
# boot. Hand-written golden.
import machine
import time

c = machine.reset_cause()
if c == machine.PWRON_RESET:
    machine.WDT(timeout=5)
    print("first boot", c)
    machine.reset()
print("after reset", c == machine.HARD_RESET)
time.sleep_ms(20)
print("watchdog stopped")
