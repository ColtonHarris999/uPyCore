# machine.soft_reset and reset_cause (extmod/modmachine.c names): a soft
# reset restarts the hart domain, which boots the image again; the I/O core
# runs on. The second boot sees SOFT_RESET. Hand-written golden.
import machine

c = machine.reset_cause()
if c == machine.PWRON_RESET:
    print("first boot", c)
    machine.soft_reset()
print("after soft reset", c == machine.SOFT_RESET)
print("uid", machine.unique_id().hex(), machine.freq())
